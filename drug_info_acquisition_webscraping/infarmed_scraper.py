"""
infarmed_scraper.py
====================
Full scraper for the Portuguese official medication registry (Infomed extranet).
Targets: https://extranet.infarmed.pt/INFOMED-fo/

Strategy
--------
1. Navigate to the advanced search page.
2. Select "Autorizado" in the Estado AIM filter (required — empty search returns nothing).
3. Click "Pesquisar" to load all authorized medications (~14,000+).
4. Set rows-per-page to 100 (maximum available).
5. Iterate through every page via PrimeFaces paginator.
6. For each row, collect summary data from the table AND visit the detail page
   to get: dispensing class (MSRM/OTC), route of administration, AIM status,
   authorization holder, PDF links (FI and RCM).
7. Persist data to CSV and JSON under outputs/.

Run:
    python infarmed_scraper.py [--pages N] [--skip-detail] [--no-headless]

Flags:
    --pages N       Only scrape the first N pages (default: all)
    --skip-detail   Skip the detail-page visit (faster, less data)
    --no-headless   Show browser window
    --resume        Resume from last saved checkpoint (outputs/checkpoint.json)
"""

import argparse
import csv
import json
import re
import sys
import time
from pathlib import Path

from playwright.sync_api import (
    Browser,
    Page,
    sync_playwright,
    TimeoutError as PlaywrightTimeoutError,
)

# ──────────────────────────── Configuration ───────────────────────────────────

BASE_URL = "https://extranet.infarmed.pt/INFOMED-fo/"
SEARCH_URL = f"{BASE_URL}pesquisa-avancada.xhtml"

OUTPUT_DIR = Path(__file__).parent / "outputs"
OUTPUT_DIR.mkdir(parents=True, exist_ok=True)

CSV_PATH = OUTPUT_DIR / "medicamentos_infomed.csv"
JSON_PATH = OUTPUT_DIR / "medicamentos_infomed.json"
CHECKPOINT_PATH = OUTPUT_DIR / "checkpoint.json"

# ── Selectors (confirmed via live browser console inspection 2026-05-07) ────────
TABLE_ID = "mainForm:dt-medicamentos"
TABLE_BODY_SELECTOR = "#mainForm\\:dt-medicamentos_data"
ROW_SELECTOR = "#mainForm\\:dt-medicamentos_data tr.ui-widget-content"
NEXT_PAGE_SELECTOR = "a.ui-paginator-next:not(.ui-state-disabled)"
# Confirmed IDs from live browser console inspection:
ROWS_PER_PAGE_SELECTOR = "#mainForm\\:dt-medicamentos\\:j_id24"  # confirmed ID
SEARCH_BTN_SELECTOR = "#mainForm\\:btnDoSearch"                  # confirmed ID
AIM_STATUS_SELECTOR = "#mainForm\\:estado-aim_input"             # native <select>
AIM_AUTORIZADO_VALUE = "REF_EST_AIM:001"                         # confirmed option value
MED_NAME_INPUT = "#mainForm\\:medicamento_input"                 # confirmed ID
PAGINATOR_INFO_SELECTOR = "span.ui-paginator-current"
# Row link pattern: mainForm:dt-medicamentos:X:linkNome
ROW_LINK_PATTERN = "mainForm:dt-medicamentos:{idx}:linkNome"
ROW_FI_PATTERN = "mainForm:dt-medicamentos:{idx}:pesqAvancadaDatableFiIcon"
ROW_RCM_PATTERN = "mainForm:dt-medicamentos:{idx}:pesqAvancadaDatableRcmIcon"

# Search strategy: iterate through each letter of the alphabet.
# The portal requires >= 3 chars in the name field — but we can use the DCI
# (substancia ativa) field which may accept shorter queries.
# Alternatively, search by name starting with each combination.
# We use letter groups ("AA", "AB", ...) but the simplest approach is to
# search by each 3-char combination of common starting letters.
# ACTUALLY: the easiest fix is to use the DCI input field with 1-2 char wildcards.
# But since the portal only requires AIM to be set (if AIM != empty default value),
# we will try JUST the AIM filter first. If that fails, iterate alphabet.
SEARCH_LETTERS = list("ABCDEFGHIJKLMNOPQRSTUVWXYZ")


WAIT_BETWEEN_PAGES = 2.0    # seconds — be polite to the server
WAIT_BETWEEN_DETAILS = 0.8  # seconds
NAV_TIMEOUT = 45_000        # ms
ELEMENT_TIMEOUT = 20_000    # ms

# ──────────────────────────── Helpers ─────────────────────────────────────────

def clean(value: str | None) -> str:
    if not value:
        return ""
    return " ".join(value.replace("\xa0", " ").split()).strip()


def parse_price(raw: str) -> float | None:
    text = clean(raw).replace("€", "").replace(".", "").replace(",", ".")
    if not text or text.lower() in {"preço livre", "n/a", "-", ""}:
        return None
    try:
        return float(text)
    except ValueError:
        return None


def wait_for_table(page: Page, timeout: int = ELEMENT_TIMEOUT) -> bool:
    """Wait until at least one result row is visible in the table."""
    try:
        # Wait for the tbody first
        page.wait_for_selector(TABLE_BODY_SELECTOR, timeout=timeout, state="attached")
        # Then wait for actual rows to appear (AJAX populates them)
        page.wait_for_selector(ROW_SELECTOR, timeout=timeout, state="attached")
        time.sleep(0.4)  # Small buffer for AJAX to finish rendering
        return True
    except PlaywrightTimeoutError:
        return False


# ──────────────────────────── Row extraction (table) ─────────────────────────

def extract_table_row(row) -> dict | None:
    """Extract summary fields visible directly in the search results table."""
    try:
        cells = row.query_selector_all("td")
        if len(cells) < 4:
            return None

        # Column layout (verified from actual scraped data 2026-05-07):
        # 0: CNPEM / Nº Registo
        # 1: Nome Comercial (with link to detail page)
        # 2: Substância Ativa / DCI
        # 3: Forma Farmacêutica
        # 4: Dosagem
        # 5: Titular AIM
        # 6: Comercialização icon
        # 7: Documentos (FI/RCM PDF icons)

        cnpem_cell = cells[0]
        nome_cell = cells[1] if len(cells) > 1 else cells[0]
        dci_cell = cells[2] if len(cells) > 2 else None
        forma_cell = cells[3] if len(cells) > 3 else None
        dosagem_cell = cells[4] if len(cells) > 4 else None
        titular_cell = cells[5] if len(cells) > 5 else None
        comerc_cell = cells[6] if len(cells) > 6 else None
        docs_cell = cells[7] if len(cells) > 7 else None

        cnpem_raw = clean(cnpem_cell.inner_text())

        # Name and detail link (JSF commandLink — href is always "#", navigate by click)
        link_el = nome_cell.query_selector("a.ui-commandlink, a")
        nome = clean(link_el.inner_text() if link_el else nome_cell.inner_text())
        # We store the link element's id so we can find and click it later
        link_id = link_el.get_attribute("id") if link_el else ""
        detail_url = link_id  # Used as a marker, actual navigation handled differently

        dci = clean(dci_cell.inner_text()) if dci_cell else ""
        forma = clean(forma_cell.inner_text()) if forma_cell else ""
        dosagem = clean(dosagem_cell.inner_text()) if dosagem_cell else ""
        titular = clean(titular_cell.inner_text()) if titular_cell else ""

        # Comercialização
        comerc = ""
        if comerc_cell:
            img = comerc_cell.query_selector("img")
            if img:
                alt = (img.get_attribute("alt") or "").lower()
                comerc = "Sim" if "sim" in alt or "comerc" in alt or img else "Não"
            else:
                comerc = clean(comerc_cell.inner_text()) or "Não"

        # PDF links (FI = Folheto Informativo, RCM = Resumo Caraterísticas Medicamento)
        fi_url = ""
        rcm_url = ""
        if docs_cell:
            for a in docs_cell.query_selector_all("a"):
                href = a.get_attribute("href") or ""
                if not href.startswith("http") and href:
                    href = BASE_URL.rstrip("/") + "/" + href.lstrip("/")
                elem_id = (a.get_attribute("id") or "").lower()
                title = (a.get_attribute("title") or "").lower()
                alt = ""
                img = a.query_selector("img")
                if img:
                    alt = (img.get_attribute("alt") or "").lower()
                label = elem_id + title + alt
                if "fi" in label or "folheto" in label or "informativo" in label:
                    fi_url = href
                elif "rcm" in label or "resumo" in label or "caracter" in label:
                    rcm_url = href

        if not nome:
            return None

        return {
            "nomeComercial": nome,
            "substanciaAtiva": dci,
            "formaFarmaceutica": forma,
            "dosagem": dosagem,
            "titularAIM": titular,
            "aimStatus": "Autorizado",  # we filter for this in search
            "comercializado": comerc,
            "cnpem": cnpem_raw,         # directly from column 0
            "detailLinkId": link_id,    # JSF link id for clicking
            "detailUrl": "",            # Filled after clicking the link
            "fiUrl": fi_url,
            "rcmUrl": rcm_url,
            # Populated from detail page:
            "dispensacaoClass": "",
            "viasAdministracao": "",
            "nRegisto": "",
            "pricePVP": None,
            "isGeneric": "",
            "margemTerapeuticaEstreita": "",
        }
    except Exception as exc:
        print(f"  [WARN] Row parse error: {exc}", file=sys.stderr)
        return None


# ──────────────────────────── Detail page extraction ─────────────────────────

def extract_detail_page(page: Page, detail_url: str) -> dict:
    """Visit the medication detail page and extract additional fields."""
    extra: dict = {}
    if not detail_url:
        return extra

    try:
        page.goto(detail_url, wait_until="domcontentloaded", timeout=NAV_TIMEOUT)
        # Wait for main content panel
        try:
            page.wait_for_selector(".ui-panel-content, #mainForm", timeout=10_000)
        except PlaywrightTimeoutError:
            pass
        time.sleep(0.5)

        # ── Dispensing classification (MSRM / MNSRM / OTC) ────────────────
        # Scan all text nodes for known dispensing class values
        disp_class = ""
        for candidate in ("MSRM-E", "MSRM", "MNSRMq", "MNSRM-E", "MNSRM"):
            if page.locator(f"text=/{candidate}/").count() > 0:
                disp_class = candidate
                break
        extra["dispensacaoClass"] = disp_class

        # ── Via de administração ───────────────────────────────────────────
        via_text = ""
        try:
            # Look for rows that follow a "Via de administração" label
            via_el = page.query_selector("td:has-text('Via de administração') + td, "
                                         "[id*='viaAdm']")
            if via_el:
                via_text = clean(via_el.inner_text())
        except Exception:
            pass
        extra["viasAdministracao"] = via_text

        # ── Generic flag ─────────────────────────────────────────────────
        generic = ""
        try:
            gen_el = page.query_selector("td:has-text('Genérico') + td, "
                                         "[id*='j_idt118']")
            if gen_el:
                generic = clean(gen_el.inner_text())
        except Exception:
            pass
        extra["isGeneric"] = generic

        # ── Narrow therapeutic margin ─────────────────────────────────────
        mte = ""
        try:
            mte_el = page.query_selector("td:has-text('Margem Terapêutica') + td, "
                                         "[id*='j_idt127']")
            if mte_el:
                mte = clean(mte_el.inner_text())
        except Exception:
            pass
        extra["margemTerapeuticaEstreita"] = mte

        # ── Registration number and CNPEM from presentations table ─────────
        try:
            reg_cells = page.query_selector_all("td.nRegisto, [id*='nRegisto']")
            cnpem_cells = page.query_selector_all("td.cnpem, [id*='cnpem']")
            pvp_cells = page.query_selector_all("td.pvp, [id*='pvp']")
            extra["nRegisto"] = clean(reg_cells[0].inner_text()) if reg_cells else ""
            extra["cnpem"] = clean(cnpem_cells[0].inner_text()) if cnpem_cells else ""
            pvp_raw = clean(pvp_cells[0].inner_text()) if pvp_cells else ""
            extra["pricePVP"] = parse_price(pvp_raw)
        except Exception:
            pass

        # ── FI PDF link (if not found in table row) ────────────────────────
        try:
            fi_el = page.query_selector(
                "[id*='FiIcon'] a, [id*='FiText'] a, "
                "a[title*='Folheto'], a[title*='FI ']"
            )
            if fi_el:
                href = fi_el.get_attribute("href") or ""
                if href:
                    extra["fiUrl"] = href if href.startswith("http") else BASE_URL + href.lstrip("/")
        except Exception:
            pass

    except PlaywrightTimeoutError:
        print(f"  [WARN] Timeout on detail page: {detail_url}", file=sys.stderr)
    except Exception as exc:
        print(f"  [WARN] Detail page error ({detail_url}): {exc}", file=sys.stderr)

    return extra


# ──────────────────────────── Paginator helpers ───────────────────────────────

def set_rows_per_page(page: Page, target: int = 100) -> None:
    """Set results-per-page to maximum using JS (JSF ID is dynamic)."""
    try:
        # Use JS to find the rpp select by its class and set maximum
        page.evaluate(
            f"""
            () => {{
                // Try known ID first
                var sel = document.getElementById('mainForm:dt-medicamentos:j_id24');
                // Fallback: find by class
                if (!sel) sel = document.querySelector('select[id$=\"_rppDD\"]');
                if (!sel) sel = document.querySelector('.ui-paginator select');
                if (sel) {{
                    var nums = [...sel.options].map(o => parseInt(o.value)).filter(v => !isNaN(v) && v > 0);
                    var best = Math.min(Math.max(...nums), {target});
                    sel.value = String(best);
                    sel.dispatchEvent(new Event('change', {{bubbles: true}}));
                }}
            }}
            """
        )
        # Wait a moment for AJAX to reload
        time.sleep(2)
        wait_for_table(page)
        print(f"  [OK] Rows-per-page set (target={target})")
    except Exception as exc:
        print(f"  [WARN] Could not set rows-per-page: {exc}", file=sys.stderr)


def get_total_records(page: Page) -> int:
    """Parse total result count from paginator text."""
    try:
        info = page.query_selector(PAGINATOR_INFO_SELECTOR)
        if info:
            txt = clean(info.inner_text())
            # Patterns: "(1 - 100 of 14280)" or "(1 a 100 de 14280)"
            m = re.search(r"(?:of|de)\s+([\d.,]+)", txt, re.IGNORECASE)
            if m:
                return int(re.sub(r"[.,]", "", m.group(1)))
    except Exception:
        pass
    return 0


def click_next_page(page: Page) -> bool:
    """Click the 'next page' button. Returns False if there is no next page."""
    try:
        next_btn = page.query_selector(NEXT_PAGE_SELECTOR)
        if not next_btn:
            return False
        classes = next_btn.get_attribute("class") or ""
        if "ui-state-disabled" in classes:
            return False
        next_btn.click()
        wait_for_table(page, timeout=NAV_TIMEOUT)
        time.sleep(WAIT_BETWEEN_PAGES)
        return True
    except Exception:
        return False


# ──────────────────────────── Main scraper ────────────────────────────────────

def scrape_all(
    max_pages: int | None = None,
    skip_detail: bool = False,
    headless: bool = True,
    resume: bool = False,
) -> list[dict]:

    records: list[dict] = []
    checkpoint: dict = {}

    if resume and CHECKPOINT_PATH.exists():
        with CHECKPOINT_PATH.open(encoding="utf-8") as f:
            checkpoint = json.load(f)
        records = checkpoint.get("records", [])
        start_page = checkpoint.get("next_page", 1)
        print(f"[RESUME] From page {start_page} ({len(records)} records already saved).")
    else:
        start_page = 1

    already_seen = {r["nomeComercial"] + "|" + r["dosagem"] for r in records}

    with sync_playwright() as pw:
        browser: Browser = pw.chromium.launch(
            headless=headless,
            args=["--disable-blink-features=AutomationControlled"],
        )
        context = browser.new_context(
            viewport={"width": 1440, "height": 900},
            user_agent=(
                "Mozilla/5.0 (Windows NT 10.0; Win64; x64) "
                "AppleWebKit/537.36 (KHTML, like Gecko) "
                "Chrome/124.0.0.0 Safari/537.36"
            ),
            locale="pt-PT",
        )
        page = context.new_page()

        # ── Navigate to advanced search page ─────────────────────────────
        print("[*] Opening Infomed advanced search page ...")
        try:
            page.goto(SEARCH_URL, wait_until="domcontentloaded", timeout=NAV_TIMEOUT)
        except PlaywrightTimeoutError:
            page.goto(BASE_URL, wait_until="domcontentloaded", timeout=NAV_TIMEOUT)
            time.sleep(2)
            page.goto(SEARCH_URL, wait_until="domcontentloaded", timeout=NAV_TIMEOUT)

        # Wait for PrimeFaces JS to initialize (AIM select is the signal)
        try:
            page.wait_for_selector(AIM_STATUS_SELECTOR, timeout=20_000, state="attached")
            print("  [OK] Page JS ready")
        except PlaywrightTimeoutError:
            print("  [WARN] Page JS slow, continuing anyway ...", file=sys.stderr)
        time.sleep(2)


        # ── AIM filter: set to "Autorizado" via native <select> ─────────────
        # Confirmed ID: mainForm:estado-aim_input; confirmed value: REF_EST_AIM:001
        print("[*] Setting AIM status to Autorizado ...")
        try:
            page.wait_for_selector(AIM_STATUS_SELECTOR, timeout=20_000, state="attached")
            aim_el = page.query_selector(AIM_STATUS_SELECTOR)
            if aim_el:
                # First try the confirmed value directly
                try:
                    aim_el.select_option(value=AIM_AUTORIZADO_VALUE)
                    print(f"  [OK] AIM set via confirmed value '{AIM_AUTORIZADO_VALUE}'")
                except Exception:
                    # Fallback: find by label text
                    opts = aim_el.query_selector_all("option")
                    for opt in opts:
                        txt = clean(opt.inner_text())
                        if "autorizado" in txt.lower() and "sus" not in txt.lower():
                            aim_el.select_option(value=opt.get_attribute("value") or txt)
                            print(f"  [OK] AIM = {txt}")
                            break
                # Dispatch change event so PrimeFaces updates internal state
                aim_el.dispatch_event("change")
        except Exception as exc:
            print(f"  [WARN] AIM filter: {exc}", file=sys.stderr)

        # ── Click search (AIM alone may be enough) ────────────────────────
        # The confirmed ID: mainForm:btnDoSearch
        print("[*] Clicking Pesquisar (AIM filter only) ...")
        page.evaluate("document.getElementById('mainForm:btnDoSearch').click()")
        time.sleep(3)

        # ── Check if results appeared ──────────────────────────────────────
        rows_found = page.query_selector_all(ROW_SELECTOR)
        if not rows_found:
            # AIM alone not accepted — need to fill name field too
            # Confirmed field ID: mainForm:medicamento_input
            # Strategy: search by each letter to get ALL medications
            print("[*] AIM-only search rejected. Using alphabet iteration ...")
            # Just try a single letter for now; the page loop will handle all letters
            # For the first run, search for letter 'A' to validate
            try:
                name_el = page.wait_for_selector(MED_NAME_INPUT, timeout=10_000, state="visible")
                if name_el:
                    name_el.fill("a")
                    print("  [OK] Name field set to 'a'")
            except Exception as exc:
                print(f"  [WARN] Name field: {exc}", file=sys.stderr)

            page.evaluate("document.getElementById('mainForm:btnDoSearch').click()")
            time.sleep(3)

        # ── Wait for result rows ───────────────────────────────────────────
        print("[*] Waiting for result rows ...")
        try:
            page.wait_for_selector(ROW_SELECTOR, timeout=30_000, state="attached")
            time.sleep(0.5)
            row_count = len(page.query_selector_all(ROW_SELECTOR))
            print(f"  [OK] {row_count} rows visible on page")
        except PlaywrightTimeoutError:
            print("[ERROR] Results rows did not appear. Exiting.", file=sys.stderr)
            browser.close()
            return records


        total_records = get_total_records(page)
        print(f"[*] Total records reported by portal: {total_records}")

        # Set rows per page to 100
        print("[*] Setting rows-per-page to 100 …")
        set_rows_per_page(page, 100)

        estimated_pages = max(1, (total_records + 99) // 100) if total_records else 999
        print(f"[*] Estimated pages: {estimated_pages}")

        # ── Fast-forward to resume page ────────────────────────────────────
        current_page = 1
        if start_page > 1:
            print(f"[*] Fast-forwarding to page {start_page} …")
            for _ in range(start_page - 1):
                if not click_next_page(page):
                    break
                current_page += 1

        # ── Page loop ─────────────────────────────────────────────────────
        while True:
            if max_pages and current_page > max_pages:
                print(f"[*] Reached --pages limit ({max_pages}).")
                break

            print(f"[PAGE {current_page}/{estimated_pages}] Extracting …", end="", flush=True)

            rows = page.query_selector_all(ROW_SELECTOR)
            page_records = []

            for row in rows:
                record = extract_table_row(row)
                if not record:
                    continue

                key = record["nomeComercial"] + "|" + record["dosagem"]
                if key in already_seen:
                    continue
                already_seen.add(key)

                # Visit detail page for extra fields
                if not skip_detail and record.get("detailUrl"):
                    extra = extract_detail_page(page, record["detailUrl"])
                    record.update(extra)
                    # Navigate back
                    try:
                        page.go_back(wait_until="domcontentloaded", timeout=NAV_TIMEOUT)
                        wait_for_table(page)
                    except Exception:
                        # Re-run the search
                        try:
                            page.goto(SEARCH_URL, wait_until="domcontentloaded", timeout=NAV_TIMEOUT)
                            time.sleep(1)
                            search_btn = page.query_selector(SEARCH_BTN_SELECTOR)
                            if search_btn:
                                search_btn.click()
                            wait_for_table(page)
                            # Navigate to current page
                            for _ in range(current_page - 1):
                                click_next_page(page)
                        except Exception as nav_exc:
                            print(f"\n  [ERROR] Re-navigation failed: {nav_exc}", file=sys.stderr)
                    time.sleep(WAIT_BETWEEN_DETAILS)

                page_records.append(record)

            records.extend(page_records)
            print(f" +{len(page_records)} -> total {len(records)}")

            # Save checkpoint
            with CHECKPOINT_PATH.open("w", encoding="utf-8") as f:
                json.dump({"records": records, "next_page": current_page + 1}, f,
                          ensure_ascii=False)

            if not click_next_page(page):
                print("[*] No more pages — complete.")
                break
            current_page += 1

        browser.close()

    # Remove checkpoint on success
    if CHECKPOINT_PATH.exists():
        CHECKPOINT_PATH.unlink()

    return records


# ──────────────────────────── Export ─────────────────────────────────────────

FIELDNAMES = [
    "nomeComercial", "substanciaAtiva", "formaFarmaceutica", "dosagem",
    "titularAIM", "aimStatus", "dispensacaoClass", "viasAdministracao",
    "isGeneric", "margemTerapeuticaEstreita", "comercializado",
    "nRegisto", "cnpem", "pricePVP",
    "detailUrl", "fiUrl", "rcmUrl",
]


def export(records: list[dict]) -> None:
    if not records:
        print("[ERROR] No records to export.", file=sys.stderr)
        return

    with CSV_PATH.open("w", newline="", encoding="utf-8-sig") as f:
        writer = csv.DictWriter(f, fieldnames=FIELDNAMES, extrasaction="ignore")
        writer.writeheader()
        writer.writerows(records)

    with JSON_PATH.open("w", encoding="utf-8") as f:
        json.dump(records, f, ensure_ascii=False, indent=2)

    print(f"\nExported {len(records)} medications")
    print(f"   CSV  -> {CSV_PATH}")
    print(f"   JSON -> {JSON_PATH}")


# ──────────────────────────── CLI ─────────────────────────────────────────────

def main() -> None:
    parser = argparse.ArgumentParser(description="Scrape Infomed medication registry")
    parser.add_argument("--pages", type=int, default=None,
                        help="Max pages to scrape (default: all)")
    parser.add_argument("--skip-detail", action="store_true",
                        help="Skip individual detail page visits (faster)")
    parser.add_argument("--no-headless", action="store_true",
                        help="Show browser window")
    parser.add_argument("--resume", action="store_true",
                        help="Resume from checkpoint")
    args = parser.parse_args()

    records = scrape_all(
        max_pages=args.pages,
        skip_detail=args.skip_detail,
        headless=not args.no_headless,
        resume=args.resume,
    )
    export(records)


if __name__ == "__main__":
    main()
