# IMPORTS
import base64
import asyncio
import importlib
import io
import json
import os
import re
import time
import urllib.request
from urllib.parse import urlencode, urljoin
from collections import OrderedDict
from pathlib import Path
from typing import Iterable

from playwright.async_api import async_playwright, TimeoutError as PlaywrightTimeoutError

# CONSTANTS
DETAIL_FI_SELECTOR = "a#detalheMedPBottomFiForm\\:detalheMedPBottomFiText"
PDF_TEXT_LIMIT = 30000
GEMINI_MODEL = "gemini-2.5-flash"


def _clean_text(value: str | None) -> str:
	if not value:
		return ""
	return " ".join(value.replace("\xa0", " ").split()).strip()


def _normalize_dci(value: str | None) -> str:
	return _clean_text(value).casefold()


def _first_record_per_dci(records: Iterable[dict]) -> list[dict]:
	first_records: OrderedDict[str, dict] = OrderedDict()
	for record in records:
		dci = _clean_text(str(record.get("dci", "")))
		key = _normalize_dci(dci)
		if not key or key in first_records:
			continue
		first_records[key] = record
	return list(first_records.values())


def _load_gemini_api_key() -> str:
	api_key = os.getenv("GEMINI_API_KEY", "").strip()
	if api_key:
		return api_key

	env_path = Path(__file__).with_name(".env")
	if env_path.exists():
		for raw_line in env_path.read_text(encoding="utf-8").splitlines():
			line = raw_line.strip()
			if not line or line.startswith("#") or "=" not in line:
				continue
			name, value = line.split("=", 1)
			if name.strip() == "GEMINI_API_KEY":
				return value.strip().strip('"').strip("'")

	return ""


def _strip_code_fences(text: str) -> str:
	cleaned = text.strip()
	if cleaned.startswith("```"):
		cleaned = re.sub(r"^```(?:json|text)?\s*", "", cleaned, flags=re.IGNORECASE)
		cleaned = re.sub(r"\s*```$", "", cleaned)
	return cleaned.strip()


def _extract_pdf_text(pdf_bytes: bytes) -> str:
	reader = None
	try:
		pypdf_module = importlib.import_module("pypdf")
		reader = pypdf_module.PdfReader(io.BytesIO(pdf_bytes))
	except Exception:
		try:
			pypdf2_module = importlib.import_module("PyPDF2")
			reader = pypdf2_module.PdfReader(io.BytesIO(pdf_bytes))
		except Exception:
			return ""

	parts: list[str] = []
	for page in reader.pages:
		try:
			page_text = page.extract_text() or ""
		except Exception:
			page_text = ""
		if page_text.strip():
			parts.append(page_text)

	return "\n\n".join(parts).strip()


def _download_pdf_bytes(pdf_url: str) -> bytes:
	request = urllib.request.Request(
		pdf_url,
		headers={
			"User-Agent": "Mozilla/5.0",
			"Accept": "application/pdf,*/*",
		},
	)
	with urllib.request.urlopen(request, timeout=60) as response:
		return response.read()


def _download_pdf_bytes_from_form(form_action: str, form_data: dict[str, str], referer_url: str, cookie_header: str = "") -> bytes:
	headers = {
		"User-Agent": "Mozilla/5.0",
		"Accept": "application/pdf,*/*",
		"Content-Type": "application/x-www-form-urlencoded; charset=UTF-8",
		"Referer": referer_url,
		"Origin": "https://extranet.infarmed.pt",
	}
	if cookie_header:
		headers["Cookie"] = cookie_header

	request = urllib.request.Request(
		form_action,
		data=urlencode(form_data).encode("utf-8"),
		headers=headers,
		method="POST",
	)
	with urllib.request.urlopen(request, timeout=120) as response:
		return response.read()


async def _ask_gemini_for_summary(dci: str, medicine_name: str, pdf_text: str) -> dict:
	api_key = _load_gemini_api_key()
	if not api_key:
		raise RuntimeError("GEMINI_API_KEY não encontrado no ambiente nem no ficheiro .env.")

	texto_base = pdf_text[:PDF_TEXT_LIMIT]
	prompt = (
		"Atua como um assistente farmacêutico especializado em extração de dados. O teu objetivo é ler o Folheto Informativo (FI) em anexo e extrair informação GENERALIZADA sobre a Substância Ativa (DCI).\n\n"
		"Regras de extração:\n"
		"1. Usa apenas o texto fornecido.\n"
		"2. Resume as indicações em frases curtas (máximo 10 palavras por item).\n"
		"3. Agrupa os efeitos indesejáveis por frequência (Frequentes, Pouco Frequentes, Raros).\n"
		"4. O campo \"modo_conservacao\" deve ser uma instrução direta.\n\n"
		"Responde EXCLUSIVAMENTE em formato JSON com esta estrutura:\n"
		"{\n"
		'  "dci": "Nome da Substância",\n'
		'  "medicamento": "Nome do Medicamento",\n'
		'  "indicacoes": ["item1", "item2"],\n'
		'  "efeitos_indesejaveis": {\n'
		'    "frequentes": ["efeito1"],\n'
		'    "outros": ["efeito2"]\n'
		"  },\n"
		'  "conservacao": "instrução curta",\n'
		'  "aviso_critico": "advertência principal sobre fígado/álcool"\n'
		"}\n\n"
		"TEXTO DO FOLHETO INFORMATIVO:\n"
		f"[texto]\n\n"
		f"DCI: {dci}\n"
		f"Medicamento: {medicine_name}\n\n"
		f"{texto_base}"
	)

	body = {
		"contents": [
			{
				"role": "user",
				"parts": [{"text": prompt}],
			}
		],
		"generationConfig": {
			"temperature": 0.2,
			"topP": 0.9,
			"maxOutputTokens": 2048,
		},
	}

	url = f"https://generativelanguage.googleapis.com/v1beta/models/{GEMINI_MODEL}:generateContent?key={api_key}"
	request = urllib.request.Request(
		url,
		data=json.dumps(body).encode("utf-8"),
		headers={"Content-Type": "application/json"},
		method="POST",
	)

	with urllib.request.urlopen(request, timeout=120) as response:
		payload = json.loads(response.read().decode("utf-8"))

	text_response = ""
	try:
		parts = payload["candidates"][0]["content"]["parts"]
		text_response = "".join(part.get("text", "") for part in parts)
	except Exception:
		text_response = json.dumps(payload, ensure_ascii=False)

	text_response = _strip_code_fences(text_response)
	
	await asyncio.sleep(0.5)
	
	try:
		return json.loads(text_response)
	except Exception:
		return {"resumo": text_response}


async def extract_informative_bill_pdf_text_by_link_from_table(records: Iterable[dict], headless: bool = True, max_workers: int = 4) -> list[dict]:
	"""Extrai o texto do folheto informativo e gera um resumo por DCI via Gemini.

	Recebe a tabela de medicamentos, usa apenas o primeiro medicamento de cada DCI
	e devolve uma lista de registos com a estrutura: DCI -> info_pdf.
	"""
	selected_records = _first_record_per_dci(records)
	if not selected_records:
		return []

	max_workers = max(1, min(max_workers, len(selected_records)))
	results_map: dict[int, dict] = {}
	inicio = time.monotonic()
	last_status_len = 0

	def format_seconds(value: float) -> str:
		total = max(0, int(value))
		horas, resto = divmod(total, 3600)
		minutos, segundos = divmod(resto, 60)
		if horas:
			return f"{horas:02d}:{minutos:02d}:{segundos:02d}"
		return f"{minutos:02d}:{segundos:02d}"

	def failed_result(record: dict, summary: str, pdf_url: str = "") -> dict:
		dci = _clean_text(str(record.get("dci", "")))
		medicine_name = _clean_text(str(record.get("nome_medicamento", "")))
		return {
			"dci": dci,
			"medicamento": medicine_name,
			"pdf_url": pdf_url,
			"info_pdf": {"resumo": summary},
		}

	async def process_record(page, record: dict) -> dict:
		dci = _clean_text(str(record.get("dci", "")))
		medicine_name = _clean_text(str(record.get("nome_medicamento", "")))
		info_url = _clean_text(str(record.get("infoUrl", "")))

		if not info_url:
			return failed_result(record, "Link de detalhe do medicamento não encontrado na tabela.")

		try:
			await page.goto(info_url, wait_until="domcontentloaded")
		except Exception:
			return failed_result(record, "Não foi possível abrir a página de detalhe do medicamento.", info_url)

		pdf_url = ""
		pdf_bytes = b""
		try:
			target_scope = page
			try:
				if await page.locator(DETAIL_FI_SELECTOR).count() == 0:
					for frame in page.frames:
						if frame == page.main_frame:
							continue
						if await frame.locator(DETAIL_FI_SELECTOR).count() > 0:
							target_scope = frame
							break
			except Exception:
				pass

			link = target_scope.locator(DETAIL_FI_SELECTOR).first
			await link.wait_for(state="visible", timeout=15000)

			form_locator = target_scope.locator("form#detalheMedPBottomFiForm").first
			form_payload = None
			if await form_locator.count() > 0:
				form_action = _clean_text(await form_locator.get_attribute("action") or "")
				form_id_value = _clean_text(
					await form_locator.locator("input[name='detalheMedPBottomFiForm']").first.get_attribute("value") or ""
				)
				view_state_value = _clean_text(
					await form_locator.locator("input[name='javax.faces.ViewState']").first.get_attribute("value") or ""
				)
				link_id = "detalheMedPBottomFiForm:detalheMedPBottomFiText"
				if form_action:
					form_payload = {
						"action": form_action,
						"data": {
							"detalheMedPBottomFiForm": form_id_value or "detalheMedPBottomFiForm",
							"javax.faces.ViewState": view_state_value,
							link_id: link_id,
						},
					}

			if form_payload:
				pdf_fetch = await target_scope.evaluate(
					"""
					async ({ action, payload }) => {
						const response = await fetch(action, {
							method: 'POST',
							credentials: 'include',
							headers: {
								'Accept': 'application/pdf,*/*',
								'Content-Type': 'application/x-www-form-urlencoded; charset=UTF-8',
							},
							body: new URLSearchParams(payload).toString(),
						});
						const blob = await response.blob();
						const dataUrl = await new Promise((resolve, reject) => {
							const reader = new FileReader();
							reader.onload = () => resolve(reader.result);
							reader.onerror = () => reject(reader.error);
							reader.readAsDataURL(blob);
						});
						return {
							url: response.url,
							contentType: response.headers.get('content-type') || '',
							dataUrl,
						};
					}
					""",
					{
						"action": form_payload["action"],
						"payload": form_payload["data"],
					},
				)
				if pdf_fetch and not pdf_fetch.get("error"):
					data_url = str(pdf_fetch.get("dataUrl", ""))
					if data_url.startswith("data:") and "," in data_url:
						pdf_bytes = base64.b64decode(data_url.split(",", 1)[1])
						pdf_url = str(pdf_fetch.get("url") or form_payload.get("action", ""))
		except PlaywrightTimeoutError:
			pass
		except Exception:
			pass

		pdf_text = ""
		if not pdf_bytes and pdf_url:
			try:
				pdf_bytes = await asyncio.to_thread(_download_pdf_bytes, pdf_url)
			except Exception:
				pdf_bytes = b""

		if pdf_bytes:
			pdf_text = _extract_pdf_text(pdf_bytes)

		if not pdf_text.strip():
			return failed_result(record, "Não foi possível extrair texto do PDF do folheto informativo.", pdf_url)

		try:
			info_pdf = await _ask_gemini_for_summary(dci, medicine_name, pdf_text)
		except Exception as exc:
			info_pdf = {"resumo": f"Erro ao enviar o texto para o Gemini: {exc}"}

		return {
			"dci": dci,
			"medicamento": medicine_name,
			"pdf_url": pdf_url,
			"info_pdf": info_pdf,
		}

	async def worker(jobs_queue: asyncio.Queue, results_queue: asyncio.Queue) -> None:
		async with async_playwright() as p:
			browser = await p.chromium.launch(headless=headless)
			context = await browser.new_context(viewport={"width": 1600, "height": 1200})
			page = await context.new_page()

			while True:
				item = await jobs_queue.get()
				if item is None:
					jobs_queue.task_done()
					return

				index, record = item
				try:
					result = await process_record(page, record)
				except Exception as exc:
					result = failed_result(record, f"Erro interno no worker: {exc}")

				await results_queue.put((index, result))
				jobs_queue.task_done()

	jobs_queue: asyncio.Queue = asyncio.Queue()
	results_queue: asyncio.Queue = asyncio.Queue()

	for index, record in enumerate(selected_records):
		jobs_queue.put_nowait((index, record))

	for _ in range(max_workers):
		jobs_queue.put_nowait(None)

	tarefas = [asyncio.create_task(worker(jobs_queue, results_queue)) for _ in range(max_workers)]

	completed = 0
	total = len(selected_records)
	while completed < total:
		index, result = await results_queue.get()
		results_map[index] = result
		completed += 1

		dci = _clean_text(str(result.get("dci", "")))
		decorrido = time.monotonic() - inicio
		media_por_item = decorrido / completed
		status = (
			f"[{dci}] "
			f"DCIs: {completed:5d}/{total} | "
			f"Tempo: {format_seconds(decorrido)} | "
			f"Estimativa total: {format_seconds(total * media_por_item)}"
		)
		padding = max(0, last_status_len - len(status))
		print(f"\r{status}{' ' * padding}", end="", flush=True)
		last_status_len = len(status)

	await asyncio.gather(*tarefas)

	results: list[dict] = []
	for index in range(total):
		results.append(results_map[index])

	print()
	return results