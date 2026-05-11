"""
pdf_leaflet_parser.py
======================
Phase 2: Download the Folheto Informativo (FI) PDF for each medication and
extract clinically important sections using pdfplumber + regex heuristics.

The extracted data enriches the JSON produced by infarmed_scraper.py with:
  - therapeuticIndications  (Indicações terapêuticas)
  - warnings                (O que precisa de saber antes de tomar)
  - adverseReactions        (Efeitos indesejáveis possíveis)
  - howToStore              (Como conservar)
  - pregnancyWarning        (Text about pregnancy/breastfeeding)
  - minAgeHint              (Any minimum age mentioned in text)
  - pregnancyRiskHint       (Keywords → mapped to FDA category)

Run (after infarmed_scraper.py):
    python pdf_leaflet_parser.py [--workers N] [--limit N]

Flags:
    --workers N   Parallel download threads (default: 4)
    --limit N     Only process the first N records (for testing)
    --pdf-dir DIR Directory to cache downloaded PDFs (default: outputs/pdfs/)
    --no-cache    Re-download even if PDF already cached
"""

import argparse
import json
import re
import sys
import time
from concurrent.futures import ThreadPoolExecutor, as_completed
from pathlib import Path

import requests
import pdfplumber

# ──────────────────────────── Paths ──────────────────────────────────────────

SCRIPT_DIR = Path(__file__).parent
OUTPUT_DIR = SCRIPT_DIR / "outputs"
JSON_PATH = OUTPUT_DIR / "medicamentos_infomed.json"
ENRICHED_JSON_PATH = OUTPUT_DIR / "medicamentos_infomed_enriched.json"
PDF_CACHE_DIR = OUTPUT_DIR / "pdfs"
PDF_CACHE_DIR.mkdir(parents=True, exist_ok=True)

# ──────────────────────────── Section headings ────────────────────────────────
# Portuguese patient leaflet (FI) follows a standard EMA structure.

SECTION_PATTERNS = {
    "indications": [
        r"1\.\s*PARA QUE",
        r"1\.\s*O QUE É .+ E PARA QUE",
        r"Indica[çc][oõ]es terap[eê]uticas",
    ],
    "before_taking": [
        r"2\.\s*O QUE PRECISA DE SABER ANTES",
        r"2\.\s*ANTES DE TOMAR",
        r"Não tome .+ se",
        r"Advert[eê]ncias e precau[çc][oõ]es",
    ],
    "how_to_take": [
        r"3\.\s*COMO TOMAR",
        r"3\.\s*POSOLOGIA",
    ],
    "adverse_reactions": [
        r"4\.\s*EFEITOS INDESEJ[AÁ]VEIS",
        r"Efeitos secund[aá]rios",
    ],
    "how_to_store": [
        r"5\.\s*COMO CONSERVAR",
        r"Conservar .{0,30}(temperatura|frigori[fí]co|congelar)",
    ],
}

# Age patterns in text
AGE_PATTERNS = [
    r"crian[çc]as? com menos de (\d+) anos",
    r"n[aã]o .{0,20}crian[çc]as? com menos de (\d+) anos",
    r"adultos e adolescentes com mais de (\d+) anos",
    r"(\d+) anos de idade",
    r"(\d+) anos ou mais",
    r"a partir dos (\d+) anos",
]

# Pregnancy risk keywords → FDA-like category hints
PREGNANCY_RISK_KEYWORDS = {
    "X": ["teratog[eê]nico", "teratogenicidade", "malforma[çc]", "n[aã]o deve ser administrado durante a gesta[çc]",
          "contraindicado.*gesta[çc]", "contraindicado.*gravidez"],
    "D": ["risco para o feto", "deve ser evitado.*gravidez", "pode causar danos", "risco fetal"],
    "C": ["n[aã]o recomendado.*gravidez", "utilizar com precau[çc]", "dados limitados"],
    "B": ["estudos em animais", "n[aã]o foram observados efeitos"],
    "A": ["seguro.*gravidez", "pode ser utilizado.*gravidez"],
}

# ──────────────────────────── PDF download ────────────────────────────────────

HEADERS = {
    "User-Agent": (
        "Mozilla/5.0 (Windows NT 10.0; Win64; x64) "
        "AppleWebKit/537.36 (KHTML, like Gecko) "
        "Chrome/124.0.0.0 Safari/537.36"
    ),
    "Accept-Language": "pt-PT,pt;q=0.9",
}
DOWNLOAD_TIMEOUT = 30  # seconds


def make_pdf_filename(record: dict) -> str:
    """Generate a safe filename for the cached PDF."""
    nome = re.sub(r"[^\w\-]", "_", record.get("nomeComercial", "unknown"))
    dosagem = re.sub(r"[^\w\-]", "_", record.get("dosagem", ""))
    return f"{nome}_{dosagem}.pdf"


def download_pdf(url: str, dest: Path, no_cache: bool = False) -> Path | None:
    """Download a PDF to dest. Returns dest on success, None on failure."""
    if not url:
        return None
    if dest.exists() and not no_cache:
        return dest  # cached
    try:
        resp = requests.get(url, headers=HEADERS, timeout=DOWNLOAD_TIMEOUT, stream=True)
        resp.raise_for_status()
        content_type = resp.headers.get("Content-Type", "")
        if "pdf" not in content_type and not url.lower().endswith(".pdf"):
            # Not a PDF — might be HTML redirect
            return None
        with dest.open("wb") as f:
            for chunk in resp.iter_content(chunk_size=65536):
                f.write(chunk)
        return dest
    except Exception as exc:
        print(f"  [WARN] PDF download failed ({url}): {exc}", file=sys.stderr)
        return None


# ──────────────────────────── PDF parsing ────────────────────────────────────

def extract_text_from_pdf(pdf_path: Path) -> str:
    """Extract all text from a PDF using pdfplumber."""
    try:
        with pdfplumber.open(pdf_path) as pdf:
            parts = []
            for p in pdf.pages:
                t = p.extract_text(x_tolerance=2, y_tolerance=3)
                if t:
                    parts.append(t)
            return "\n".join(parts)
    except Exception as exc:
        print(f"  [WARN] PDF read error ({pdf_path.name}): {exc}", file=sys.stderr)
        return ""


def find_section(text: str, patterns: list[str], next_section_start: int = 0) -> str:
    """
    Find the first occurrence of any pattern and return text up to the next
    numbered section (e.g. '3.', '4.') or a configurable end marker.
    """
    for pattern in patterns:
        m = re.search(pattern, text, re.IGNORECASE)
        if m:
            start = m.start()
            # End at next numbered section heading (e.g. '\n3.', '\n4.')
            end_match = re.search(
                r"\n\s*[3-9]\.\s+[A-ZÁÉÍÓÚÂÊÎÔÛÃÕ]",
                text[m.end():],
                re.IGNORECASE,
            )
            end = m.end() + (end_match.start() if end_match else 2000)
            snippet = text[start:end].strip()
            # Truncate to a reasonable length
            return snippet[:3000]
    return ""


def extract_min_age(text: str) -> int | None:
    """Heuristically find the minimum age mentioned in the leaflet."""
    ages = []
    for pattern in AGE_PATTERNS:
        for m in re.finditer(pattern, text, re.IGNORECASE):
            try:
                ages.append(int(m.group(1)))
            except Exception:
                pass
    if ages:
        return min(ages)
    return None


def extract_pregnancy_risk(text: str) -> str | None:
    """Map text keywords to FDA pregnancy risk category hint."""
    lower = text.lower()
    for category in ("X", "D", "C", "B", "A"):
        for kw in PREGNANCY_RISK_KEYWORDS[category]:
            if re.search(kw, lower, re.IGNORECASE):
                return category
    return None


def parse_fi_pdf(pdf_path: Path) -> dict:
    """Extract structured fields from the Folheto Informativo PDF."""
    text = extract_text_from_pdf(pdf_path)
    if not text:
        return {}

    result = {}

    # Clinical sections
    result["therapeuticIndications"] = find_section(text, SECTION_PATTERNS["indications"])
    result["warnings"] = find_section(text, SECTION_PATTERNS["before_taking"])
    result["adverseReactions"] = find_section(text, SECTION_PATTERNS["adverse_reactions"])
    result["howToStore"] = find_section(text, SECTION_PATTERNS["how_to_store"])

    # Extract pregnancy-specific paragraph from warnings
    preg_match = re.search(
        r"(gravidez|grávida|amament|lactação).{0,1500}",
        result.get("warnings", ""),
        re.IGNORECASE | re.DOTALL,
    )
    result["pregnancyWarning"] = preg_match.group(0)[:1500].strip() if preg_match else ""

    # Heuristic age and pregnancy risk
    result["minAgeHint"] = extract_min_age(text)
    result["pregnancyRiskHint"] = extract_pregnancy_risk(
        result.get("warnings", "") + " " + result.get("therapeuticIndications", "")
    )

    return result


# ──────────────────────────── Worker ─────────────────────────────────────────

def process_record(record: dict, no_cache: bool) -> dict:
    """Download FI PDF and enrich a single record dict."""
    fi_url = record.get("fiUrl", "")
    if not fi_url:
        return record

    pdf_name = make_pdf_filename(record)
    pdf_path = PDF_CACHE_DIR / pdf_name

    pdf_file = download_pdf(fi_url, pdf_path, no_cache=no_cache)
    if not pdf_file:
        return record

    parsed = parse_fi_pdf(pdf_file)
    record.update(parsed)
    return record


# ──────────────────────────── Main ───────────────────────────────────────────

def main() -> None:
    parser = argparse.ArgumentParser(description="Enrich Infomed JSON with FI PDF data")
    parser.add_argument("--workers", type=int, default=4,
                        help="Parallel download threads")
    parser.add_argument("--limit", type=int, default=None,
                        help="Only process first N records")
    parser.add_argument("--no-cache", action="store_true",
                        help="Re-download PDFs even if cached")
    args = parser.parse_args()

    if not JSON_PATH.exists():
        print(f"[ERROR] {JSON_PATH} not found. Run infarmed_scraper.py first.", file=sys.stderr)
        sys.exit(1)

    with JSON_PATH.open(encoding="utf-8") as f:
        records: list[dict] = json.load(f)

    subset = records[:args.limit] if args.limit else records
    remaining = records[args.limit:] if args.limit else []

    print(f"[*] Processing {len(subset)} records with {args.workers} workers …")

    enriched = []
    with ThreadPoolExecutor(max_workers=args.workers) as pool:
        futures = {pool.submit(process_record, r.copy(), args.no_cache): i
                   for i, r in enumerate(subset)}
        done = 0
        for future in as_completed(futures):
            done += 1
            try:
                enriched.append(future.result())
            except Exception as exc:
                print(f"  [ERROR] Worker failed: {exc}", file=sys.stderr)
                enriched.append(subset[futures[future]])
            if done % 50 == 0 or done == len(subset):
                print(f"  Progress: {done}/{len(subset)}", flush=True)
            time.sleep(0.1)

    # Merge enriched subset with any remaining records
    all_records = enriched + remaining

    with ENRICHED_JSON_PATH.open("w", encoding="utf-8") as f:
        json.dump(all_records, f, ensure_ascii=False, indent=2)

    with_fi = sum(1 for r in enriched if r.get("therapeuticIndications"))
    print(f"\n✅ Enriched {with_fi}/{len(subset)} records with FI data")
    print(f"   Output → {ENRICHED_JSON_PATH}")


if __name__ == "__main__":
    main()
