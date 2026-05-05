# IMPORTS
import time
import asyncio
from pathlib import Path
from typing import Iterable
import string
import itertools

from playwright.async_api import async_playwright, TimeoutError as PlaywrightTimeoutError

try:
    from .utils import ( 
        find_dci_frame,
        get_statistics
    )
except Exception:
    from utils import (
        find_dci_frame,
        get_statistics
    )

# CONSTANTS
BASE_URL = "https://www.infarmed.pt/web/infarmed/servicos-on-line/pesquisa-do-medicamento"

DCI_INPUT_SELECTOR = "input#form\\:dci_input"
AUTOCOMPLETE_PANEL_SELECTOR = "ul.ui-autocomplete-items"

todas_substancias = set()

# AUTOCORRECT 3 Leters Combination to get DCIs
async def extract_all_dci(max_workers: int = 6):
    # Gerar combinações: aaa, aab, aac... zzz
     
    combinacoes = [''.join(i) for i in itertools.product(string.ascii_lowercase, repeat=3)]
    total_combinacoes = len(combinacoes)
    inicio = time.monotonic()
    
    todas_substancias = set()
    last_status_len = 0
    processed = 0
    completed_estimate = 0

    def format_seconds(value: float) -> str:
        total = max(0, int(value))
        horas, resto = divmod(total, 3600)
        minutos, segundos = divmod(resto, 60)
        if horas:
            return f"{horas:02d}:{minutos:02d}:{segundos:02d}"
        return f"{minutos:02d}:{segundos:02d}"

    async def process_term(target, locator, termo: str) -> tuple[int, set[str]]:
        found_names: set[str] = set()

        try:
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
                await locator.type(termo, delay=50)
            except Exception:
                return 0, found_names

            try:
                await target.wait_for_selector(AUTOCOMPLETE_PANEL_SELECTOR, state="visible", timeout=3000)
                sugestoes = await target.query_selector_all(f"{AUTOCOMPLETE_PANEL_SELECTOR} li")
                for el in sugestoes:
                    nome = await el.get_attribute("data-item-label")
                    if nome:
                        found_names.add(nome)
            except PlaywrightTimeoutError:
                pass
        except Exception:
            return 0, found_names

        return len(found_names), found_names

    async def worker(worker_id: int, termos: list[tuple[int, str]], fila_resultados: asyncio.Queue):
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
                return

            locator = target.locator(DCI_INPUT_SELECTOR)

            for index, termo in termos:
                dcis_nesta_combinacao, encontrados = await process_term(target, locator, termo)
                await fila_resultados.put((index, termo, dcis_nesta_combinacao, encontrados))

            await browser.close()

    lotes = [[] for _ in range(max_workers)]
    for index, termo in enumerate(combinacoes):
        lotes[index % max_workers].append((index, termo))

    fila_resultados: asyncio.Queue = asyncio.Queue()
    tarefas = [asyncio.create_task(worker(worker_id, lote, fila_resultados)) for worker_id, lote in enumerate(lotes) if lote]

    while processed < total_combinacoes:
        index, termo, dcis_nesta_combinacao, encontrados = await fila_resultados.get()
        todas_substancias.update(encontrados)
        processed += 1

        percentagem = (processed / total_combinacoes) * 100
        decorrido = time.monotonic() - inicio
        media_por_combinacao = decorrido / processed
        this_stats = await get_statistics()
        total_stats = this_stats[0]

        status = (
            f"[{termo}] "
            f"DCIs nesta: {dcis_nesta_combinacao:3d} | "
            f"Combinações: {processed:5d}/{total_combinacoes} | "
            f"Concluído: {percentagem:6.2f}% | "
            f"Encontradas: {len(todas_substancias):5d} | "
            f"Tempo: {format_seconds(decorrido)} | "
            f"Estimativa total: {format_seconds(total_combinacoes * media_por_combinacao)} | "
            f"Stats DCI: {total_stats:5d}"
        )
        padding = max(0, last_status_len - len(status))
        print(f"\r{status}{' ' * padding}", end="", flush=True)
        last_status_len = len(status)

    await asyncio.gather(*tarefas)

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
