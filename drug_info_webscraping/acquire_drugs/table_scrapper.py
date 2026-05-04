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
BASE_URL = "https://www.infarmed.pt/web/infarmed/servicos-on-line/pesquisa-do-medicamento"

OUTPUT_DIR = Path.cwd() / ".." / "outputs"
OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
CSV_PATH = OUTPUT_DIR / "medicamentos_infomed.csv"
JSON_PATH = OUTPUT_DIR / "medicamentos_infomed.json"

TABLE_SELECTOR = "#form\\:tbl"
ROW_SELECTOR = "#form\\:tbl_data tr"

DCI_INPUT_SELECTOR = "input#form\\:dci_input"
AUTOCOMPLETE_PANEL_SELECTOR = "ul.ui-autocomplete-items"

# VARIABLES
statistics_infomed = [0, 0, 0, ""] # [nDCIs, nMedicamentos, nApresentações, lastUpdate]

todas_substancias = set()

# return list with the data in the table for a given DCI term 
# (array of dictionaries with keys: Nregistro, dci, nome_medicamento, forma_farmaceutica, dosagem, tamanho_embalagem, cnpem, pricePVP, pricePVPnotified, priceUtente, pricePensionist, pdf_folheto)
async def extract_table_from_dci(dci_term: str) -> list[dict]:
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

	records: list[dict] = []

	async with async_playwright() as p:
		browser = await p.chromium.launch(headless=False)
		context = await browser.new_context(viewport={"width": 1600, "height": 1200})
		page = await context.new_page()
		await page.goto(BASE_URL, wait_until="networkidle")

		# localizar iframe onde o formulário está
		try:
			await page.wait_for_selector("iframe[src*='pesquisaMedicamento.jsf']", state="attached", timeout=20000)
		except PlaywrightTimeoutError:
			await browser.close()
			return records

		frame = None
		for f in page.frames:
			if "pesquisaMedicamento.jsf" in f.url:
				frame = f
				break

		target = frame or page

		# preencher campo de DCI e disparar autocomplete/seleção (seguindo padrão de dci_scrapper)
		if dci_term:
			try:
				locator = target.locator(DCI_INPUT_SELECTOR)

				try:
					await locator.scroll_into_view_if_needed()
					await locator.click()
					await locator.fill("")
				except Exception:
					try:
						await target.evaluate("sel => { const el = document.querySelector(sel); if (el) el.value = ''; }", DCI_INPUT_SELECTOR)
					except Exception:
						pass

				try:
					await locator.focus()
					await locator.type(dci_term, delay=100)
				except Exception:
					await browser.close()
					return records

				# esperar painel de sugestões; se aparecer, clicar na primeira sugestão
				try:
					await target.wait_for_selector(AUTOCOMPLETE_PANEL_SELECTOR, state="visible", timeout=3000)
					sugestoes = await target.query_selector_all(f"{AUTOCOMPLETE_PANEL_SELECTOR} li")
					if sugestoes:
						try:
							await sugestoes[0].click()
						except Exception:
							# se click falhar, apenas continue e pressione Enter
							await locator.press("Enter")
					else:
						await locator.press("Enter")
				except PlaywrightTimeoutError:
					# sem sugestões, tentar submeter com Enter
					try:
						await locator.press("Enter")
					except Exception:
						pass

				# Tentar clicar no botão de pesquisa caso exista (algumas páginas requerem clique)
				try:
					search_button = await target.query_selector("button[id*='Pesquisar'], button[type='submit'], input[type='submit'][value*='Pesquisa']")
					if search_button:
						try:
							await search_button.click()
						except Exception:
							pass
				except Exception:
					pass

				# Algumas vezes selecionar a DCI não dispara a pesquisa; preencher também o campo 'nome_input' e submeter
				try:
					try:
						dci_value = await locator.input_value()
					except Exception:
						dci_value = ""

					if not dci_value:
						# tentar obter texto da primeira sugestão
						try:
							primeiro = await target.query_selector(f"{AUTOCOMPLETE_PANEL_SELECTOR} li")
							dci_value = (await primeiro.inner_text()) if primeiro else ""
						except Exception:
							dci_value = ""

					if dci_value:
						nome_input = await target.query_selector("input#form\\:nome_input")
						if nome_input:
							try:
								await nome_input.fill(dci_value)
								await nome_input.press("Enter")
								# tentar clicar no botão de pesquisa após preencher nome_input
								try:
									search_button2 = await target.query_selector("button[id*='Pesquisar'], button[type='submit'], input[type='submit'][value*='Pesquisa']")
									if search_button2:
										await search_button2.click()
								except Exception:
									pass
							except Exception:
								pass
				except Exception:
					pass

				# aguardar carregamento de resultados
				try:
					await page.wait_for_load_state("networkidle", timeout=10000)
				except Exception:
					await asyncio.sleep(1)
			except Exception:
				await browser.close()
				return records

		# procurar tabela
		try:
			try:
				await target.wait_for_selector(TABLE_SELECTOR, timeout=8000, state="attached")
				rows = await target.query_selector_all(ROW_SELECTOR)
			except PlaywrightTimeoutError:
				await page.wait_for_selector(TABLE_SELECTOR, timeout=8000, state="attached")
				rows = await page.query_selector_all(ROW_SELECTOR)
		except PlaywrightTimeoutError:
			await browser.close()
			return records

		for row in rows:
			try:
				async def at_text(sel: str) -> str:
					el = await row.query_selector(sel)
					return clean_text(await el.inner_text()) if el else ""

				nRegisto_text = await at_text(".registo-column")
				try:
					nRegisto = int(nRegisto_text.replace("Nº registo", "").strip() or 0)
				except ValueError:
					nRegisto = 0

				dci = await at_text(".subs-column")
				nome = await at_text(".nome-column span[id$=':nomeMed']")
				if not nome:
					nome = await at_text(".nome-column")

				forma = await at_text(".forma-column")
				dosagem = await at_text(".dosagem-column")
				tamanho = await at_text(".tamanho-column")
				try:
					cnpem = int((await at_text(".cnpem-column")).replace("CNPEM", "").strip() or 0)
				except ValueError:
					cnpem = 0

				pvp = parse_currency(await at_text(".pvp-column"))
				pvp_notificado = parse_currency(await at_text(".notif-column"))
				price_utente = parse_currency(await at_text(".utente-column"))
				price_pension = parse_currency(await at_text(".pension-column"))

				comercialized = await at_text(".comerc-column")
				is_generic = await at_text(".ui-helper-hidden")

				info_el = await row.query_selector(".info-column a[href]")
				info_url = await info_el.get_attribute("href") if info_el else ""

				records.append({
					"nRegisto": nRegisto,
					"dci": dci.replace("Substância Ativa/DCI", "").strip(),
					"nome_medicamento": nome.replace("Nome do medicamento", "").strip(),
					"forma_farmaceutica": forma.replace("Forma farmacêutica", "").strip(),
					"dosagem": dosagem.replace("Dosagem", "").strip(),
					"tamanho_embalagem": tamanho.replace("Tamanho da embalagem", "").strip(),
					"cnpem": cnpem,
					"pricePVP": pvp,
					"pricePVPnotified": pvp_notificado,
					"priceUtente": price_utente,
					"pricePensionist": price_pension,
					"commercialized": comercialized,
					"isGeneric": is_generic,
					"infoUrl": info_url,
				})
			except Exception:
				continue

		await browser.close()

	return records

