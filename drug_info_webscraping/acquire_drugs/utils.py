# IMPORTS
import csv
import json
import time
import asyncio
from pathlib import Path
from typing import Iterable
import string
import itertools

from playwright.async_api import async_playwright, TimeoutError as PlaywrightTimeoutError

# CONSTANTS
STATISTICS_URL = "https://extranet.infarmed.pt/INFOMED-fo/"
BASE_URL = "https://www.infarmed.pt/web/infarmed/servicos-on-line/pesquisa-do-medicamento"
DCI_IFRAME_SELECTOR = "iframe[src*='pesquisaMedicamento.jsf']"

OUTPUT_DIR = Path.cwd() / ".." / "outputs"
OUTPUT_DIR.mkdir(parents=True, exist_ok=True)

# VARIABLES
statistics_infomed = [0, 0, 0, ""] # [nDCIs, nMedicamentos, nApresentações, lastUpdate]

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
    
        
# EXPORT FUNCTIONS
def export_dcis(dcis: Iterable[str], filename_prefix: str = "dcis_infomed") -> None:
	"""Exportar lista de DCIs para JSON e CSV"""
	dcis_list = sorted(list(set(dcis)))
	
	if not dcis_list:
		raise RuntimeError("Nenhuma DCI foi fornecida para exportar.")
	
	csv_path = OUTPUT_DIR / f"{filename_prefix}.csv"
	json_path = OUTPUT_DIR / f"{filename_prefix}.json"
	
	# Exportar para CSV
	with csv_path.open("w", newline="", encoding="utf-8-sig") as csv_file:
		writer = csv.writer(csv_file)
		writer.writerow(["DCI"])
		for dci in dcis_list:
			writer.writerow([dci])
	
	# Exportar para JSON
	with json_path.open("w", encoding="utf-8") as json_file:
		json.dump({
			"total": len(dcis_list),
			"dcis": dcis_list,
			"data_exportacao": time.strftime("%Y-%m-%d %H:%M:%S")
		}, json_file, ensure_ascii=False, indent=2)
	
	print(f"✓ Exportação de DCIs concluída: {len(dcis_list)} substâncias")
	print(f"  CSV: {csv_path}")
	print(f"  JSON: {json_path}")


def export_tables(records: Iterable[dict], filename_prefix: str = "medicamentos_infomed") -> None:
	"""Exportar tabelas de medicamentos para JSON e CSV"""
	records_list = list(records)
	
	if not records_list:
		raise RuntimeError("Nenhum medicamento foi extraído para exportar.")
	
	csv_path = OUTPUT_DIR / f"{filename_prefix}.csv"
	json_path = OUTPUT_DIR / f"{filename_prefix}.json"
	
	# Obter nomes de colunas do primeiro registo
	fieldnames = list(records_list[0].keys())
	
	# Exportar para CSV
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
	print(f"  CSV: {csv_path}")
	print(f"  JSON: {json_path}")
