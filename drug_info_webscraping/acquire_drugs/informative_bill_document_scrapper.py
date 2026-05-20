# IMPORTS
import base64
import asyncio
import importlib
import io
import json
import os
import re
import time
import socket
import urllib.error
import urllib.request
from urllib.parse import urlencode, urljoin
from collections import OrderedDict
from pathlib import Path
from typing import Iterable

from playwright.async_api import async_playwright, TimeoutError as PlaywrightTimeoutError

# CONSTANTS
DETAIL_FI_SOURCES = (
	("detalheMedPBottomFiForm", "a#detalheMedPBottomFiForm\\:detalheMedPBottomFiText"),
	("detalheMedPBottomEmaForm", "a#detalheMedPBottomEmaForm\\:detalheMedPBottomEmaText"),
)
PDF_TEXT_LIMIT = 30000
GEMINI_MODEL = "gemini-2.5-flash"
GEMINI_REQUEST_TIMEOUT_SECONDS = 180
GEMINI_MAX_ATTEMPTS = 4
GEMINI_BASE_BACKOFF_SECONDS = 2.0


_GEMINI_KEY_LOCK = asyncio.Lock()
_GEMINI_KEY_INDEX = 0


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


def _load_gemini_api_keys() -> list[str]:
	keys: list[str] = []
	for env_name in ("GEMINI_API_KEY", "GEMINI_API_KEY_1", "GEMINI_API_KEY_2"):
		value = os.getenv(env_name, "").strip()
		if value and value not in keys:
			keys.append(value)

	env_path = Path(__file__).with_name(".env")
	if env_path.exists():
		for raw_line in env_path.read_text(encoding="utf-8").splitlines():
			line = raw_line.strip()
			if not line or line.startswith("#") or "=" not in line:
				continue
			name, value = line.split("=", 1)
			name = name.strip()
			if name in {"GEMINI_API_KEY", "GEMINI_API_KEY_1", "GEMINI_API_KEY_2"}:
				cleaned_value = value.strip().strip('"').strip("'")
				if cleaned_value and cleaned_value not in keys:
					keys.append(cleaned_value)

	return keys


async def _acquire_gemini_api_key() -> str:
	keys = _load_gemini_api_keys()
	if not keys:
		return ""

	global _GEMINI_KEY_INDEX
	async with _GEMINI_KEY_LOCK:
		key = keys[_GEMINI_KEY_INDEX % len(keys)]
		_GEMINI_KEY_INDEX = (_GEMINI_KEY_INDEX + 1) % len(keys)
		return key


def _load_gemini_max_concurrent_requests() -> int:
	raw_value = os.getenv("GEMINI_MAX_CONCURRENT_REQUESTS", "1").strip()
	try:
		return max(1, int(raw_value))
	except ValueError:
		return 1


def _strip_code_fences(text: str) -> str:
	cleaned = text.strip()
	if cleaned.startswith("```"):
		cleaned = re.sub(r"^```(?:json|text)?\s*", "", cleaned, flags=re.IGNORECASE)
		cleaned = re.sub(r"\s*```$", "", cleaned)
	return cleaned.strip()


def _extract_json_from_text(text: str) -> str | None:
	"""Try to extract the first balanced JSON object from a text blob.
	Returns the JSON substring or None if not found.
	"""
	if not text:
		return None
	# Quick regex: find the first '{' and attempt to find a matching '}' by scanning
	start_positions = [m.start() for m in re.finditer(r"\{", text)]
	for start in start_positions:
		stack = 0
		for i in range(start, len(text)):
			ch = text[i]
			if ch == "{":
				stack += 1
			elif ch == "}":
				stack -= 1
				if stack == 0:
					candidate = text[start:i + 1]
					return candidate
	return None


def _log_raw_gemini_response(dci: str, medicine_name: str, text: str) -> None:
	try:
		out_dir = Path(__file__).parent.joinpath("outputs", "gemini_raw_responses")
		out_dir.mkdir(parents=True, exist_ok=True)
		safe_name = re.sub(r"[^0-9A-Za-z._-]", "_", f"{dci}_{medicine_name}")[:200]
		path = out_dir.joinpath(f"{safe_name}.txt")
		path.write_text(text[:20000], encoding="utf-8")
	except Exception:
		pass


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


def _looks_like_pdf(pdf_bytes: bytes) -> bool:
	return pdf_bytes.startswith(b"%PDF-")


async def _ask_gemini_for_summary(
	dci: str,
	medicine_name: str,
	pdf_text: str,
	request_semaphore: asyncio.Semaphore | None = None,
) -> dict:
	api_keys = _load_gemini_api_keys()
	if not api_keys:
		raise RuntimeError("GEMINI_API_KEY não encontrado no ambiente nem no ficheiro .env.")

	texto_base = pdf_text[:PDF_TEXT_LIMIT]
	prompt = (
		"Extrai informação do Folheto Informativo abaixo e responde APENAS em JSON:\n\n"
		"{\n"
		'  "dci": "Substância Ativa",\n'
		'  "medicamento": "Nome do Medicamento",\n'
		'  "indicacoes": ["indicação 1", "indicação 2"],\n'
		'  "indicacoes_key": ["palavra-chave curta 1", "palavra-chave curta 2"],\n'
		'  "efeitos_indesejaveis": {"frequentes": ["efeito1"], "outros": ["efeito2"]},\n'
		'  "conservacao": "como conservar",\n'
		'  "aviso_critico": "aviso importante",\n'
		'  "idade_minima": 0,\n'
		'  "gravidez_seguro": "sim|nao|condicionado",\n'
		'  "gravidez_nota": "texto explicativo sobre gravidez (se aplicável)",\n'
		'  "amamentacao_seguro": "sim|nao|condicionado",\n'
		'  "amamentacao_nota": "texto explicativo sobre amamentação (se aplicável)"\n'
		"}\n\n"
		"INSTRUÇÕES IMPORTANTES:\n"
		"- Retorna SOMENTE um objeto JSON válido com os campos indicados.\n"
		"- Para os campos 'gravidez_seguro' e 'amamentacao_seguro' usa exatamente os valores: 'sim', 'nao' ou 'condicionado'.\n"
		"- Para 'idade_minima' devolve um número inteiro quando possível, ou 0 se não houver indicação clara.\n"
		"- Adiciona o campo 'indicacoes_key': uma lista com 1 ou 2 palavras por cada entrada em 'indicacoes'. Mantém a ordem correspondente. As palavras devem ser curtas, em português, preferencialmente substantivos ou termos compostos curtos, sem pontuação final.\n\n"
		"TEXTO DO FOLHETO:\n"
		f"{texto_base}\n\n"
		f"DCI identificada: {dci}\n"
		f"Medicamento: {medicine_name}"
	)

	body = {
		"contents": [
			{
				"role": "user",
				"parts": [{"text": prompt}],
			}
		],
		"generationConfig": {
			# prefer deterministic outputs and maximum allowed output
			"temperature": 0.0,
			"topP": 1.0,
			"maxOutputTokens": 65536,
		},
	}

	payload = None
	last_error: Exception | None = None
	for attempt in range(1, GEMINI_MAX_ATTEMPTS + 1):
		api_key = await _acquire_gemini_api_key()
		if not api_key:
			break

		url = f"https://generativelanguage.googleapis.com/v1beta/models/{GEMINI_MODEL}:generateContent?key={api_key}"
		request = urllib.request.Request(
			url,
			data=json.dumps(body).encode("utf-8"),
			headers={"Content-Type": "application/json"},
			method="POST",
		)

		try:
			if request_semaphore is None:
				with urllib.request.urlopen(request, timeout=GEMINI_REQUEST_TIMEOUT_SECONDS) as response:
					payload = json.loads(response.read().decode("utf-8"))
			else:
				async with request_semaphore:
					with urllib.request.urlopen(request, timeout=GEMINI_REQUEST_TIMEOUT_SECONDS) as response:
						payload = json.loads(response.read().decode("utf-8"))
			break
		except urllib.error.HTTPError as exc:
			last_error = exc
			if exc.code != 429:
				raise
		except (urllib.error.URLError, socket.timeout, TimeoutError) as exc:
			last_error = exc

		if attempt < GEMINI_MAX_ATTEMPTS:
			await asyncio.sleep(GEMINI_BASE_BACKOFF_SECONDS * attempt)

	if payload is None:
		raise RuntimeError(f"Erro ao enviar o texto para o Gemini: {last_error or 'resposta vazia'}")

	text_response = ""
	try:
		parts = payload["candidates"][0]["content"]["parts"]
		text_response = "".join(part.get("text", "") for part in parts)
	except Exception:
		text_response = json.dumps(payload, ensure_ascii=False)

	text_response = _strip_code_fences(text_response)

	# Log raw response for debugging (truncated)
#	_log_raw_gemini_response(dci, medicine_name, text_response)

	await asyncio.sleep(0.5)

	# First simple attempt: direct json.loads
	try:
		result = json.loads(text_response)
	except json.JSONDecodeError:
		# Try to extract a JSON substring from the response
		candidate = _extract_json_from_text(text_response)
		if candidate:
			try:
				result = json.loads(candidate)
			except json.JSONDecodeError:
				result = None
		else:
			result = None

	if not result:
		# as a last-ditch effort, try to remove obvious trailing ellipses
		cleaned = re.sub(r"\.\.\.+$", "", text_response).strip()
		candidate = _extract_json_from_text(cleaned)
		if candidate:
			try:
				result = json.loads(candidate)
			except Exception:
				result = None

	if not result:
		return {"resumo": f"JSON inválido do Gemini: {text_response[:1000]}..."}

	# Validar se temos os campos mínimos esperados
	if not all(key in result for key in ["dci", "medicamento", "indicacoes"]):
		return {"resumo": f"JSON incompleto do Gemini: {text_response[:1000]}..."}

	# Normalizar/garantir presença dos novos campos
	# idade_minima: tentar converter para int se possível
	if "idade_minima" in result:
		try:
			if result["idade_minima"] is None or result["idade_minima"] == "":
				result["idade_minima"] = 0
			else:
				result["idade_minima"] = int(result["idade_minima"])
		except Exception:
			try:
				digits = re.search(r"(\d+)", str(result.get("idade_minima", "")))
				result["idade_minima"] = int(digits.group(1)) if digits else 0
			except Exception:
				result["idade_minima"] = 0
	else:
		result["idade_minima"] = 0

	# garantir chaves de gravidez/amamentação com valores padrão se ausentes
	for key in ["gravidez_seguro", "gravidez_nota", "amamentacao_seguro", "amamentacao_nota"]:
		if key not in result:
			result[key] = ""

	return result


async def extract_informative_bill_pdf_text_by_link_from_table(records: Iterable[dict], headless: bool = True, max_workers: int = 4) -> list[dict]:
	"""Extrai o texto do folheto informativo e gera um resumo por DCI via Gemini.

	Recebe a tabela de medicamentos, usa apenas o primeiro medicamento de cada DCI
	e devolve uma lista de registos com a estrutura: DCI -> info_pdf.
	"""
	selected_records = _first_record_per_dci(records)
	if not selected_records:
		return []

	gemini_request_semaphore = asyncio.Semaphore(_load_gemini_max_concurrent_requests())

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
			try:
				await page.wait_for_load_state("networkidle", timeout=10000)
			except Exception:
				pass
			try:
				documents_link = page.get_by_role("link", name="Documentos para o Público")
				if await documents_link.count() > 0:
					await documents_link.first.click()
					await page.wait_for_timeout(1000)
			except Exception:
				pass
		except Exception:
			return failed_result(record, "Não foi possível abrir a página de detalhe do medicamento.", info_url)

		pdf_url = ""
		pdf_bytes = b""
		try:
			target_scope = page
			form_id = ""
			link_selector = ""
			for candidate_form_id, candidate_selector in DETAIL_FI_SOURCES:
				try:
					if await page.locator(candidate_selector).count() > 0:
						target_scope = page
						form_id = candidate_form_id
						link_selector = candidate_selector
						break
					for frame in page.frames:
						if frame == page.main_frame:
							continue
						if await frame.locator(candidate_selector).count() > 0:
							target_scope = frame
							form_id = candidate_form_id
							link_selector = candidate_selector
							break
					if form_id:
						break
				except Exception:
					continue

			if not form_id:
				try:
					all_form_ids = await page.evaluate(
						"""
						() => Array.from(document.querySelectorAll('form[id^="detalheMedPBottom"]')).map(form => form.id)
						"""
					)
					for candidate_form_id in all_form_ids:
						if candidate_form_id.endswith("FiForm") or candidate_form_id.endswith("EmaForm"):
							candidate_selector = f"form#{candidate_form_id} a"
							if await page.locator(candidate_selector).count() > 0:
								target_scope = page
								form_id = candidate_form_id
								link_selector = candidate_selector
								break
				except Exception:
					pass

				if not form_id:
					generic_candidates = (
						("detalheMedPBottomFiForm", "a:has-text('Folheto Informativo')"),
						("detalheMedPBottomEmaForm", "a:has-text('Folheto Informativo')"),
						("detalheMedPBottomFiForm", "a[onclick*='detalheMedPBottomFiForm']"),
						("detalheMedPBottomEmaForm", "a[onclick*='detalheMedPBottomEmaForm']"),
					)
					for candidate_form_id, candidate_selector in generic_candidates:
						try:
							if await page.locator(candidate_selector).count() > 0:
								target_scope = page
								form_id = candidate_form_id
								link_selector = candidate_selector
								break
							for frame in page.frames:
								if frame == page.main_frame:
									continue
								if await frame.locator(candidate_selector).count() > 0:
									target_scope = frame
									form_id = candidate_form_id
									link_selector = candidate_selector
									break
							if form_id:
								break
						except Exception:
							continue

			if not form_id:
				return failed_result(record, "Não foi possível localizar o folheto informativo na página de detalhe.", info_url)

			link = target_scope.locator(link_selector).first
			await link.wait_for(state="visible", timeout=15000)

			try:
				async with page.expect_download(timeout=15000) as download_info:
					await link.click()
				download = await download_info.value
				download_path = await download.path()
				if download_path:
					pdf_bytes = Path(download_path).read_bytes()
					pdf_url = download.url or pdf_url
			except PlaywrightTimeoutError:
				pass
			except Exception:
				pass

			form_locator = target_scope.locator(f"form#{form_id}").first
			form_payload = None
			if await form_locator.count() > 0:
				form_action = _clean_text(await form_locator.get_attribute("action") or "")
				form_id_value = _clean_text(
					await form_locator.locator(f"input[name='{form_id}']").first.get_attribute("value") or ""
				)
				view_state_value = _clean_text(
					await form_locator.locator("input[name='javax.faces.ViewState']").first.get_attribute("value") or ""
				)
				link_id = f"{form_id}:{form_id.replace('Form', 'Text')}"
				if form_action:
					form_payload = {
						"action": form_action,
						"data": {
							form_id: form_id_value or form_id,
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

		if pdf_bytes and not _looks_like_pdf(pdf_bytes):
			snippet = pdf_bytes[:200].decode("utf-8", errors="replace").strip()
			return failed_result(
				record,
				f"A resposta recebida não parece ser um PDF válido: {snippet[:160]}",
				pdf_url,
			)

		pdf_text = ""
		if not pdf_bytes and pdf_url:
			try:
				pdf_bytes = await asyncio.to_thread(_download_pdf_bytes, pdf_url)
			except Exception:
				pdf_bytes = b""

		if pdf_bytes and _looks_like_pdf(pdf_bytes):
			pdf_text = _extract_pdf_text(pdf_bytes)

		if not pdf_text.strip():
			return failed_result(record, "Não foi possível extrair texto do PDF do folheto informativo.", pdf_url)

		try:
			info_pdf = await _ask_gemini_for_summary(
				dci,
				medicine_name,
				pdf_text,
				request_semaphore=gemini_request_semaphore,
			)
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