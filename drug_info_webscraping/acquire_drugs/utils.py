# IMPORTS
import csv
import json
import time
from pathlib import Path
from typing import Iterable

from playwright.async_api import async_playwright, TimeoutError as PlaywrightTimeoutError

# CONSTANTS
STATISTICS_URL = "https://extranet.infarmed.pt/INFOMED-fo/"
BASE_URL = "https://www.infarmed.pt/web/infarmed/servicos-on-line/pesquisa-do-medicamento"
DCI_IFRAME_SELECTOR = "iframe[src*='pesquisaMedicamento.jsf']"

OUTPUT_DIR = Path(__file__).parent.parent / "outputs"
OUTPUT_DIR.mkdir(parents=True, exist_ok=True)

DCI_CHECKPOINT_PATH = OUTPUT_DIR / "dci_extraction_checkpoint.json"

# VARIABLES
statistics_infomed = [0, 0, 0, ""] # [nDCIs, nMedicamentos, nApresentações, lastUpdate]


def write_dci_checkpoint(last_completed_index: int, last_completed_term: str, total_processed: int | None = None) -> None:
    payload = {
        "last_completed_index": last_completed_index,
        "last_completed_term": last_completed_term,
        "total_processed": total_processed if total_processed is not None else last_completed_index + 1,
        "updated_at": time.strftime("%Y-%m-%d %H:%M:%S"),
    }

    with DCI_CHECKPOINT_PATH.open("w", encoding="utf-8") as checkpoint_file:
        json.dump(payload, checkpoint_file, ensure_ascii=False, indent=2)


def read_dci_checkpoint() -> dict | None:
    if not DCI_CHECKPOINT_PATH.exists():
        return None

    try:
        with DCI_CHECKPOINT_PATH.open("r", encoding="utf-8") as checkpoint_file:
            data = json.load(checkpoint_file)
    except Exception:
        return None

    if not isinstance(data, dict):
        return None

    return data


def delete_dci_checkpoint() -> None:
    if DCI_CHECKPOINT_PATH.exists():
        DCI_CHECKPOINT_PATH.unlink()


def save_dcis_json(dcis: Iterable[str], filename_prefix: str = "dcis_infomed_incomplete") -> Path:
    dcis_list = sorted(list(set(dcis)))
    json_path = OUTPUT_DIR / f"{filename_prefix}.json"

    with json_path.open("w", encoding="utf-8") as json_file:
        json.dump({
            "total": len(dcis_list),
            "dcis": dcis_list,
            "data_exportacao": time.strftime("%Y-%m-%d %H:%M:%S")
        }, json_file, ensure_ascii=False, indent=2)

    return json_path

# GET IFRAME NAME

async def find_dci_frame(page, timeout: int = 20000):
    await page.wait_for_selector(DCI_IFRAME_SELECTOR, state="attached", timeout=timeout)

    for frame in page.frames:
        if "pesquisaMedicamento.jsf" in frame.url:
            return frame

    return None

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
        try:
            context = await browser.new_context()
            page = await context.new_page()
            try:
                await page.goto(STATISTICS_URL, wait_until="domcontentloaded", timeout=60000)
            except PlaywrightTimeoutError:
                return statistics_infomed

            try:
                await page.wait_for_selector(".count1", timeout=10000)
            except PlaywrightTimeoutError:
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

            return statistics_infomed
        finally:
            await browser.close()  
        
# EXPORT FUNCTIONS
def export_dcis(dcis: Iterable[str], filename_prefix: str = "dcis_infomed", csv_option: bool = False) -> None:
    """Exportar lista de DCIs para JSON e CSV"""
    dcis_list = sorted(list(set(dcis)))

    if not dcis_list:
        raise RuntimeError("Nenhuma DCI foi fornecida para exportar.")

    csv_path = OUTPUT_DIR / f"{filename_prefix}.csv"
    json_path = save_dcis_json(dcis_list, filename_prefix=filename_prefix)

    # Exportar para CSV
    if csv_option:
        with csv_path.open("w", newline="", encoding="utf-8-sig") as csv_file:
            writer = csv.writer(csv_file)
            writer.writerow(["DCI"])
            for dci in dcis_list:
                writer.writerow([dci])

    print(f"✓ Exportação de DCIs concluída: {len(dcis_list)} substâncias")
    if csv_option:
        print(f"  CSV: {csv_path}")
    print(f"  JSON: {json_path}")

def export_tables(records: Iterable[dict], filename_prefix: str = "medicamentos_infomed", csv_option: bool = False) -> None:
    """Exportar tabelas de medicamentos para JSON e CSV"""
    records_list = list(records)

    if not records_list:
        raise RuntimeError("Nenhum medicamento foi extraído para exportar.")

    csv_path = OUTPUT_DIR / f"{filename_prefix}.csv"
    json_path = OUTPUT_DIR / f"{filename_prefix}.json"

    # Obter nomes de colunas do primeiro registo
    fieldnames = list(records_list[0].keys())

    # Exportar para CSV
    if csv_option:
        with csv_path.open("w", newline="", encoding="utf-8-sig") as csv_file:
            writer = csv.DictWriter(csv_file, fieldnames=fieldnames)
            writer.writeheader()
            writer.writerows(records_list)

    # Exportar para JSON
    with json_path.open("w", encoding="utf-8") as json_file:
        json.dump({
            "total": len(records_list),
            "records": records_list,
            "data_exportacao": time.strftime("%Y-%m-%d %H:%M:%S")
        }, json_file, ensure_ascii=False, indent=2)

    print(f"✓ Exportação de medicamentos concluída: {len(records_list)} registos")
    if csv_option:
        print(f"  CSV: {csv_path}")
    print(f"  JSON: {json_path}")


def export_informative_bill_per_dci(records: Iterable[dict], filename_prefix: str = "informative_bill_per_dci", csv_option: bool = False) -> None:
    """Exportar a lista de resumo do folheto informativo por DCI para JSON e CSV."""
    records_list = list(records)

    if not records_list:
        raise RuntimeError("Nenhum resumo de folheto informativo foi fornecido para exportar.")

    csv_path = OUTPUT_DIR / f"{filename_prefix}.csv"
    json_path = OUTPUT_DIR / f"{filename_prefix}.json"

    flat_rows: list[dict] = []
    for record in records_list:
        info_pdf = record.get("info_pdf", {})
        if isinstance(info_pdf, dict):
            info_pdf_text = json.dumps(info_pdf, ensure_ascii=False)
        else:
            info_pdf_text = str(info_pdf)

        flat_rows.append({
            "dci": record.get("dci", ""),
            "medicamento": record.get("medicamento", ""),
            "pdf_url": record.get("pdf_url", ""),
            "info_pdf": info_pdf_text,
        })

    if csv_option:
        with csv_path.open("w", newline="", encoding="utf-8-sig") as csv_file:
            writer = csv.DictWriter(csv_file, fieldnames=["dci", "medicamento", "pdf_url", "info_pdf"])
            writer.writeheader()
            writer.writerows(flat_rows)

    with json_path.open("w", encoding="utf-8") as json_file:
        json.dump({
            "total": len(records_list),
            "records": records_list,
            "data_exportacao": time.strftime("%Y-%m-%d %H:%M:%S")
        }, json_file, ensure_ascii=False, indent=2)

    print(f"✓ Exportação do folheto informativo concluída: {len(records_list)} registos")
    if csv_option:
        print(f"  CSV: {csv_path}")
    print(f"  JSON: {json_path}")
    
    
# IMPORT FUNCTIONS
def import_dcis_from_json(json_path: Path = OUTPUT_DIR / "dcis_infomed.json") -> list[str]:
    """Importar lista de DCIs a partir de um ficheiro JSON exportado."""
    if not json_path.exists():
        raise FileNotFoundError(f"O ficheiro {json_path} não foi encontrado.")
    
    with json_path.open("r", encoding="utf-8") as json_file:
        data = json.load(json_file)
        dcis = data.get("dcis", [])
        print(f"✓ Importação concluída: {len(dcis)} DCIs carregadas de {json_path}")
        return dcis

def import_table_from_json(json_path: Path = OUTPUT_DIR / "medicamentos_infomed.json") -> list[dict]:
    """Importar tabela de medicamentos a partir de um ficheiro JSON exportado."""
    if not json_path.exists():
        raise FileNotFoundError(f"O ficheiro {json_path} não foi encontrado.")
    
    with json_path.open("r", encoding="utf-8") as json_file:
        data = json.load(json_file)
        records = data.get("records", [])
        print(f"✓ Importação concluída: {len(records)} registos carregados de {json_path}")
        return records
    
def import_informative_bill_from_json(json_path: Path = OUTPUT_DIR / "informative_bill_per_dci.json") -> list[dict]:
    """Importar resumos do folheto informativo por DCI a partir de um ficheiro JSON exportado."""
    if not json_path.exists():
        raise FileNotFoundError(f"O ficheiro {json_path} não foi encontrado.")
    
    with json_path.open("r", encoding="utf-8") as json_file:
        data = json.load(json_file)
        records = data.get("records", [])
        print(f"✓ Importação concluída: {len(records)} registos carregados de {json_path}")
        return records
    