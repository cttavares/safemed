# IMPORTS
import csv
import json
import time
from pathlib import Path
from typing import Iterable
import string
import itertools

from playwright.async_api import async_playwright, TimeoutError as PlaywrightTimeoutError

# CONSTANTS
STATISTICS_URL = "https://extranet.infarmed.pt/INFOMED-fo/"
BASE_URL = "https://www.infarmed.pt/web/infarmed/servicos-on-line/pesquisa-do-medicamento"

OUTPUT_DIR = Path.cwd() / ".." / "outputs"
OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
CSV_PATH = OUTPUT_DIR / "medicamentos_infomed.csv"
JSON_PATH = OUTPUT_DIR / "medicamentos_infomed.json"

TABLE_SELECTOR = "#form\\:tbl"
ROW_SELECTOR = "#form\\:tbl_data tr"
DCI_INPUT_SELECTOR = "input#form\\:dci_input"
AUTOCOMPLETE_PANEL_SELECTOR = "ul.ui-autocomplete-items"
DCI_IFRAME_SELECTOR = "iframe[src*='pesquisaMedicamento.jsf']"

# VARIABLES
statistics_infomed = [0, 0, 0, ""] # [nDCIs, nMedicamentos, nApresentações, lastUpdate]

todas_substancias = set()


async def find_dci_frame(page, timeout: int = 20000):
    await page.wait_for_selector(DCI_IFRAME_SELECTOR, state="attached", timeout=timeout)

    for frame in page.frames:
        if "pesquisaMedicamento.jsf" in frame.url:
            return frame

    return None


# GET IFRAME NAME
async def get_iframe_name():
    browser = None
    try:
        async with async_playwright() as p:
            browser = await p.chromium.launch(headless=False)
            context = await browser.new_context()
            page = await context.new_page()
            await page.goto(BASE_URL, wait_until="domcontentloaded")

            frame = await find_dci_frame(page)
            if frame:
                return frame.name or frame.url

            print("No frame with the DCI input was found.")
            return None
    finally:
        if browser:
            await browser.close()
            

# GET STATISTICS OF CURRENT INFOMED DATABASE
# number of: dcis, medicamentos, apresentações, last update

async def get_statistics():
    async with async_playwright() as p:
        browser = await p.chromium.launch(headless=True)
        context = await browser.new_context()
        page = await context.new_page()
        await page.goto(STATISTICS_URL, wait_until="domcontentloaded")

        try:
            await page.wait_for_selector(".count1", timeout=10000)
        except PlaywrightTimeoutError:
            await browser.close()
            return statistics_infomed

        async def _get_number_from_selector(sel: str) -> int:
            # 1. Esperar que o seletor esteja visível
            await page.wait_for_selector(sel, state="visible")
            
            # 2. Pequena pausa ou espera até a animação terminar. 
            # O Infomed usa JS para animar. Vamos esperar até que o número seja "estável".
            # Uma forma robusta é esperar 1-2 segundos ou verificar o conteúdo.
            await page.wait_for_timeout(1500) # Espera 1.5 segundos para a animação concluir

            el = await page.query_selector(sel)
            if not el:
                return 0
            
            # Usamos o inner_text() que é mais fiável para o que o utilizador vê
            raw = await el.inner_text()
            
            import re
            # Removemos tudo o que não seja dígito para evitar problemas com pontos/espaços
            digits = "".join(re.findall(r'\d+', raw))
            
            try:
                return int(digits) if digits else 0
            except ValueError:
                return 0

        dci_val = await _get_number_from_selector(".count1")
        med_val = await _get_number_from_selector(".count2")
        emp_val = await _get_number_from_selector(".count3")

        # data: procurar dd/mm/yyyy em todo o HTML
        content = await page.content()
        import re
        date_match = re.search(r"(\d{2}/\d{2}/\d{4})", content)
        date_text = date_match.group(1) if date_match else ""

        statistics_infomed[0] = dci_val
        statistics_infomed[1] = med_val
        statistics_infomed[2] = emp_val
        statistics_infomed[3] = date_text

        await browser.close()
        return statistics_infomed

# AUTOCORRECT 3 Leters Combination to get DCIs
async def extract_all_dci():
    # Gerar combinações: aaa, aab, aac... zzz
     
    combinacoes = [''.join(i) for i in itertools.product(string.ascii_lowercase, repeat=3)]
    total_combinacoes = len(combinacoes)
    inicio = time.monotonic()
    
    todas_substancias = set()

    async with async_playwright() as p:
        browser = await p.chromium.launch(headless=True)
        context = await browser.new_context()
        page = await context.new_page()
        
        await page.goto(BASE_URL, wait_until="domcontentloaded")

        dci_frame = await find_dci_frame(page)
        target = dci_frame or page

        try:
            await target.wait_for_selector(DCI_INPUT_SELECTOR, state="visible", timeout=15000)
        except PlaywrightTimeoutError:
            print(f"Input selector not found after navigating to {BASE_URL}")
            await browser.close()
            return sorted(list(todas_substancias))

        locator = target.locator(DCI_INPUT_SELECTOR)
        last_status_len = 0

        for i, termo in enumerate(combinacoes):
            dcis_nesta_combinacao = 0
            
            try:
                # Limpar o input
                try:
                    await locator.scroll_into_view_if_needed()
                    await locator.click()
                    await locator.fill("")
                except Exception:
                    try:
                        await target.evaluate("sel => { const el = document.querySelector(sel); if (el) el.value = ''; }", DCI_INPUT_SELECTOR)
                    except Exception as e:
                        # Silenciosamente continua
                        pass

                # Digitar o termo
                try:
                    await locator.focus()
                    await locator.type(termo, delay=50)
                except Exception as e:
                    # Silenciosamente continua
                    pass
                else:
                    # Espera o painel aparecer
                    try:
                        await target.wait_for_selector(AUTOCOMPLETE_PANEL_SELECTOR, state="visible", timeout=3000)

                        sugestoes = await target.query_selector_all(f"{AUTOCOMPLETE_PANEL_SELECTOR} li")
                        for el in sugestoes:
                            nome = await el.get_attribute("data-item-label")
                            if nome:
                                todas_substancias.add(nome)
                                dcis_nesta_combinacao += 1
                    except PlaywrightTimeoutError:
                        pass

            except Exception as e:
                # Silenciosamente continua
                pass
            
            # Mostrar progresso numa linha estável
            percentagem = ((i + 1) / total_combinacoes) * 100
            decorrido = time.monotonic() - inicio
            media_por_combinacao = decorrido / (i + 1)
            total_stats = statistics_infomed[0]
            
            if total_stats <= 0:
                this_stats = await get_statistics()
                total_stats = this_stats[0]

            def format_seconds(value: float) -> str:
                total = max(0, int(value))
                horas, resto = divmod(total, 3600)
                minutos, segundos = divmod(resto, 60)
                if horas:
                    return f"{horas:02d}:{minutos:02d}:{segundos:02d}"
                return f"{minutos:02d}:{segundos:02d}"
            
            status = (
                f"[{termo}] "
                f"DCIs nesta: {dcis_nesta_combinacao:3d} | "
                f"Combinações: {i + 1:5d}/{total_combinacoes} | "
                f"Concluído: {percentagem:6.2f}% | "
                f"Encontradas: {len(todas_substancias):5d} | "
                f"Tempo: {format_seconds(decorrido)} | "
                f"Estimativa total: {format_seconds(total_combinacoes * media_por_combinacao)} | "
                f"Stats DCI: {total_stats:5d}"
            )
            padding = max(0, last_status_len - len(status))
            print(f"\r{status}{' ' * padding}", end="", flush=True)
            last_status_len = len(status)
        await browser.close()

        print()
    
    return sorted(list(todas_substancias))

async def extract_dci_for_term(termo: str) -> Iterable[str]:
    substancias = set()
    
    async with async_playwright() as p:
        browser = await p.chromium.launch(headless=False)
        context = await browser.new_context()
        page = await context.new_page()
        
        await page.goto(BASE_URL, wait_until="domcontentloaded")

        dci_frame = await find_dci_frame(page)
        target = dci_frame or page

        try:
            await target.wait_for_selector(DCI_INPUT_SELECTOR, state="visible", timeout=15000)
        except PlaywrightTimeoutError:
            print(f"Input selector not found after navigating to {BASE_URL}")
            await browser.close()
            return sorted(list(substancias))

        try:
            locator = target.locator(DCI_INPUT_SELECTOR)
            try:
                await locator.scroll_into_view_if_needed()
                await locator.click()
                await locator.fill("")
            except Exception:
                try:
                    await target.evaluate("sel => { const el = document.querySelector(sel); if (el) el.value = ''; }", DCI_INPUT_SELECTOR)
                except Exception as e:
                    print(f"Couldn't clear input via JS for termo {termo}: {e}")

            try:
                await locator.focus()
                await locator.type(termo, delay=100)
            except Exception as e:
                print(f"Typing into input failed for termo {termo}: {e}")
                return sorted(list(substancias))

            # Espera o painel aparecer. Se não houver resultados, o timeout dispara.
            try:
                await target.wait_for_selector(AUTOCOMPLETE_PANEL_SELECTOR, state="visible", timeout=3000)

                sugestoes = await target.query_selector_all(f"{AUTOCOMPLETE_PANEL_SELECTOR} li")
                for el in sugestoes:
                    nome = await el.get_attribute("data-item-label")
                    if nome:
                        substancias.add(nome)
            except PlaywrightTimeoutError:
                # Se der timeout (não apareceu sugestão), passamos à próxima letra
                pass

        except Exception as e:
            print(f"Erro no termo {termo}: {e}")

        await browser.close()
    
    return sorted(list(substancias))



# TABLE EXTRACTION FROM INFOMED PORTAL
def clean_text(value: str | None) -> str:
    if not value:
        return ""
    return " ".join(value.replace("\xa0", " ").split()).strip()


def parse_currency(value: str | None) -> float | None:
    text = clean_text(value).replace("€", "").replace(".", "").replace(",", ".")
    if not text or text.lower() in {"preço livre", "n/a"}:
        return None
    try:
        return float(text)
    except ValueError:
        return None


async def extract_row(row) -> dict:
    async def cell(selector: str) -> str:
        element = await row.query_selector(selector)
        if element:
            text = await element.inner_text()
            return clean_text(text)
        return ""

    nome_element = await row.query_selector(".nome-column span[id$=':nomeMed']")
    info_link = await row.query_selector(".info-column a[href]")

    if nome_element:
        nome_medicamento = clean_text(await nome_element.inner_text())
    else:
        nome_medicamento = await cell(".nome-column")

    registo_text = await cell(".registo-column")
    registo_val = int(registo_text.replace("Nº registo", "").strip() or 0)
    
    dci_text = await cell(".subs-column")
    dci_val = dci_text.replace("Substância Ativa/DCI", "").strip()
    
    brand_name = nome_medicamento.replace("Nome do medicamento", "").strip()
    
    form_text = await cell(".forma-column")
    form_val = form_text.replace("Forma farmacêutica", "").strip()
    
    dosage_text = await cell(".dosagem-column")
    dosage_val = dosage_text.replace("Dosagem", "").strip()
    
    size_text = await cell(".tamanho-column")
    size_val = size_text.replace("Tamanho da embalagem", "").strip()
    
    cnpem_text = await cell(".cnpem-column")
    cnpem_val = int(cnpem_text.replace("CNPEM", "").strip() or 0)
    
    pvp_text = await cell(".pvp-column")
    pvp_val = parse_currency(pvp_text.replace("Preço (PVP)", "").strip())
    
    utente_text = await cell(".utente-column")
    utente_val = parse_currency(utente_text.replace("Preço Utente", "").strip())
    
    pension_text = await cell(".pension-column")
    pension_val = parse_currency(pension_text.replace("Preço Pensionistas", "").strip())
    
    comerc_text = await cell(".comerc-column")
    comerc_val = comerc_text.replace("Comerc.", "").strip()
    
    generic_text = await cell(".ui-helper-hidden")
    generic_val = generic_text.replace("Genérico", "").strip()
    
    info_url = ""
    if info_link:
        info_url = await info_link.get_attribute("href") or ""

    return {
        "nRegisto": registo_val,
        "dci": dci_val,
        "brandName": brand_name,
        "form": form_val,
        "dosage": dosage_val,
        "boxsize": size_val,
        "cnpem": cnpem_val,
        "pricePVP": pvp_val,
        "priceUtente": utente_val,
        "pricePensionista": pension_val,
        "commercialized": comerc_val,
        "isGeneric": generic_val,
        "infoUrl": info_url,
    }


async def scrape_infomed_table(search_term: str = "") -> list[dict]:
    records: list[dict] = []

    async with async_playwright() as playwright:
        browser = await playwright.chromium.launch(headless=True)
        page = await browser.new_page(viewport={"width": 1600, "height": 1200})
        await page.goto(BASE_URL, wait_until="networkidle")

        # Encontrar o iframe com pesquisaMedicamento.jsf
        iframe_element = await find_dci_frame(page, timeout=20000)
        if not iframe_element:
            await browser.close()
            raise RuntimeError("Não foi possível encontrar o iframe do INFOMED")
        
        frame = iframe_element
        
        # Se houver um termo de busca, tentar preencher e submeter
        if search_term:
            try:
                nome_input = await frame.query_selector("input#form\\:nome_input")
                if nome_input:
                    await nome_input.fill(search_term)
                    # Tentar encontrar um botão de busca
                    search_button = await frame.query_selector("button[id*='Pesquisar'], button[type='submit'], input[type='submit'][value*='Pesquisa']")
                    if search_button:
                        await search_button.click()
                    else:
                        # Se não houver botão, tentar pressionar Enter
                        await nome_input.press("Enter")
                    # Aguardar resultado da busca com timeout maior
                    await page.wait_for_load_state("networkidle", timeout=10000)
                else:
                    print("Campo de busca 'nome_input' não encontrado")
            except Exception as e:
                print(f"Erro ao preencher campo de busca: {e}")

        try:
            # Tentar encontrar a tabela no iframe
            try:
                await frame.wait_for_selector(TABLE_SELECTOR, timeout=8000, state="attached")
                rows = await frame.query_selector_all(ROW_SELECTOR)
                if rows:
                    print(f"Encontrada tabela com {len(rows)} linhas no iframe")
            except PlaywrightTimeoutError:
                # Se não encontrar no iframe, tentar na página principal
                print("Tabela não encontrada no iframe, tentando na página principal...")
                await page.wait_for_selector(TABLE_SELECTOR, timeout=8000, state="attached")
                rows = await page.query_selector_all(ROW_SELECTOR)
                if rows:
                    print(f"Encontrada tabela com {len(rows)} linhas na página principal")
        except PlaywrightTimeoutError:
            await browser.close()
            print(f"⚠️ A tabela não foi encontrada. O site pode exigir interação manual ou JavaScript adicional.")
            print(f"Sugestão: Verifique se a busca por '{search_term}' produz resultados no site INFOMED.")
            return []

        try:
            for row in rows:
                try:
                    records.append(await extract_row(row))
                except Exception as exc:
                    print(f"Linha ignorada por erro de parsing: {exc}")
        except Exception as e:
            print(f"Erro ao processar linhas da tabela: {e}")

        await browser.close()

    return records


def export_records(records: Iterable[dict]) -> None:
    records = list(records)
    if not records:
        raise RuntimeError("Nenhum medicamento foi extraído.")

    fieldnames = list(records[0].keys())
    with CSV_PATH.open("w", newline="", encoding="utf-8-sig") as csv_file:
        writer = csv.DictWriter(csv_file, fieldnames=fieldnames)
        writer.writeheader()
        writer.writerows(records)

    with JSON_PATH.open("w", encoding="utf-8") as json_file:
        json.dump(records, json_file, ensure_ascii=False, indent=2)

    print(f"Exportação concluída: {len(records)} registos")
    print(f"CSV: {CSV_PATH}")
    print(f"JSON: {JSON_PATH}")