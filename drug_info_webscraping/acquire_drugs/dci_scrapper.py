# IMPORTS
import time
import asyncio
import sys
from typing import Iterable
import string
import itertools

from playwright.async_api import async_playwright, TimeoutError as PlaywrightTimeoutError

try:
    from .utils import ( 
        delete_dci_checkpoint,
        find_dci_frame,
        get_statistics,
        import_dcis_from_json,
        read_dci_checkpoint,
        save_dcis_json,
        write_dci_checkpoint,
    )
except Exception:
    from utils import (
        delete_dci_checkpoint,
        find_dci_frame,
        get_statistics,
        import_dcis_from_json,
        read_dci_checkpoint,
        save_dcis_json,
        write_dci_checkpoint,
    )

# CONSTANTS
BASE_URL = "https://www.infarmed.pt/web/infarmed/servicos-on-line/pesquisa-do-medicamento"

DCI_INPUT_SELECTOR = "input#form\\:dci_input"
AUTOCOMPLETE_PANEL_SELECTOR = "ul.ui-autocomplete-items"

todas_substancias = set()

# AUTOCORRECT 3 Leters Combination to get DCIs
async def extract_all_dci(max_workers: int = 6):
    max_workers = max(1, max_workers)
    combinacoes = [''.join(i) for i in itertools.product(string.ascii_lowercase, repeat=3)]
    total_combinacoes = len(combinacoes)
    inicio = time.monotonic()

    checkpoint = read_dci_checkpoint()
    todas_substancias = set()
    checkpoint_committed_index = -1
    start_index = 0

    if checkpoint:
        try:
            checkpoint_committed_index = int(checkpoint.get("last_completed_index", -1))
        except Exception:
            checkpoint_committed_index = -1

        checkpoint_term = str(checkpoint.get("last_completed_term", ""))

        if checkpoint_committed_index >= 0:
            print(f"Checkpoint encontrado: última combinação concluída '{checkpoint_term}' (índice {checkpoint_committed_index}).")
            resposta = (await asyncio.to_thread(input, "Queres continuar daí? [S/n]: ")).strip().lower()
            if resposta in {"n", "nao", "não", "no"}:
                delete_dci_checkpoint()
                checkpoint_committed_index = -1
                print("Checkpoint removido. Vou recomeçar do zero.")
            else:
                start_index = min(checkpoint_committed_index + 1, total_combinacoes)
                try:
                    todas_substancias.update(import_dcis_from_json())
                    print(f"Vou continuar daí com {len(todas_substancias)} substâncias já guardadas.")
                    print(f"A retomar da combinação {start_index + 1}/{total_combinacoes}.")
                except FileNotFoundError:
                    print("Aviso: o JSON parcial não foi encontrado. Vou apagar o checkpoint e recomeçar do zero.")
                    delete_dci_checkpoint()
                    checkpoint_committed_index = -1
                    start_index = 0
                except Exception as e:
                    print(f"Aviso: não foi possível carregar o JSON parcial: {e}")
                    delete_dci_checkpoint()
                    checkpoint_committed_index = -1
                    start_index = 0

    if start_index >= total_combinacoes:
        print("Todas as combinações já tinham sido concluídas no checkpoint.")
        delete_dci_checkpoint()
        return sorted(list(todas_substancias))

    processed_since_start = 0
    completed_indices: set[int] = set()
    stop_event = asyncio.Event()
    checkpoint_write_counter = 0
    CHECKPOINT_WRITE_INTERVAL = 50  # Escrever checkpoint a cada 50 resultados completos
    ui_state = {
        "buffer": "",
        "status": "A aguardar arranque...",
        "initialized": False,
    }

    def format_seconds(value: float) -> str:
        total = max(0, int(value))
        horas, resto = divmod(total, 3600)
        minutos, segundos = divmod(resto, 60)
        if horas:
            return f"{horas:02d}:{minutos:02d}:{segundos:02d}"
        return f"{minutos:02d}:{segundos:02d}"

    def redraw_ui() -> None:
        if not ui_state["initialized"]:
            sys.stdout.write("\n[INPUT] Escreve 'stop for now' e carrega Enter para parar e guardar progresso.\n")
            sys.stdout.write(f"> {ui_state['buffer']}\n")
            sys.stdout.write(f"[STATUS] {ui_state['status']}")
            ui_state["initialized"] = True
            sys.stdout.flush()
            return

        sys.stdout.write("\x1b[2F")
        sys.stdout.write("\x1b[2K\r")
        sys.stdout.write("[INPUT] Escreve 'stop for now' e carrega Enter para parar e guardar progresso.\n")
        sys.stdout.write("\x1b[2K\r")
        sys.stdout.write(f"> {ui_state['buffer']}\n")
        sys.stdout.write("\x1b[2K\r")
        sys.stdout.write(f"[STATUS] {ui_state['status']}")
        sys.stdout.flush()

    async def watch_for_stop_command():
        try:
            import msvcrt
        except Exception:
            return

        ui_state["buffer"] = ""
        redraw_ui()

        while not stop_event.is_set():
            while msvcrt.kbhit():
                char = msvcrt.getwch()

                if char in ("\r", "\n"):
                    print()
                    command = ui_state["buffer"].strip().lower()
                    ui_state["buffer"] = ""

                    if command == "stop for now":
                        stop_event.set()
                        print("[AVISO] Paragem solicitada. A guardar o progresso.")
                        return

                    if command:
                        print("[INPUT] Comando ignorado. Continua a execução.")
                    redraw_ui()
                elif char == "\b":
                    if ui_state["buffer"]:
                        ui_state["buffer"] = ui_state["buffer"][:-1]
                        redraw_ui()
                else:
                    ui_state["buffer"] += char
                    redraw_ui()

            await asyncio.sleep(0.2)

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
            browser = None
            try:
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
                    return

                locator = target.locator(DCI_INPUT_SELECTOR)

                for index, termo in termos:
                    if stop_event.is_set():
                        break

                    dcis_nesta_combinacao, encontrados = await process_term(target, locator, termo)
                    await fila_resultados.put((index, termo, dcis_nesta_combinacao, encontrados))
            finally:
                if browser:
                    await browser.close()
                await fila_resultados.put((None, None, None, None))

    lotes = [[] for _ in range(max_workers)]
    for index in range(start_index, total_combinacoes):
        termo = combinacoes[index]
        lotes[(index - start_index) % max_workers].append((index, termo))

    fila_resultados: asyncio.Queue = asyncio.Queue()
    tarefas = [asyncio.create_task(worker(worker_id, lote, fila_resultados)) for worker_id, lote in enumerate(lotes) if lote]
    total_workers = len(tarefas)
    watcher_task = asyncio.create_task(watch_for_stop_command())

    try:
        workers_finished = 0

        while workers_finished < total_workers:
            index, termo, dcis_nesta_combinacao, encontrados = await fila_resultados.get()

            if index is None:
                workers_finished += 1
                continue

            if stop_event.is_set():
                continue

            todas_substancias.update(encontrados)
            processed_since_start += 1
            completed_indices.add(index)

            # Apenas marca indices sequenciais como completos (resolve concorrência)
            while (checkpoint_committed_index + 1) in completed_indices:
                checkpoint_committed_index += 1

            # Escreve checkpoint apenas a cada N resultados ou quando parado
            checkpoint_write_counter += 1
            if checkpoint_write_counter >= CHECKPOINT_WRITE_INTERVAL:
                write_dci_checkpoint(
                    checkpoint_committed_index,
                    combinacoes[checkpoint_committed_index] if checkpoint_committed_index >= 0 else "",
                    total_processed=checkpoint_committed_index + 1,
                )
                checkpoint_write_counter = 0

            processed_total = start_index + processed_since_start
            percentagem = (processed_total / total_combinacoes) * 100
            decorrido = time.monotonic() - inicio
            media_por_combinacao = decorrido / processed_since_start if processed_since_start else 0
            this_stats = await get_statistics()
            total_stats = this_stats[0]

            status = (
                f"[{termo}] "
                f"DCIs nesta: {dcis_nesta_combinacao:3d} | "
                f"Combinações: {processed_total:5d}/{total_combinacoes} | "
                f"Concluído: {percentagem:6.2f}% | "
                f"Encontradas: {len(todas_substancias):5d} | "
                f"Tempo: {format_seconds(decorrido)} | "
                f"Estimativa total: {format_seconds(total_combinacoes * media_por_combinacao)} | "
                f"Stats DCI: {total_stats:5d}"
            )
            ui_state["status"] = status
            redraw_ui()
    finally:
        stop_event.set()
        watcher_task.cancel()
        try:
            await watcher_task
        except asyncio.CancelledError:
            pass

        if tarefas:
            await asyncio.gather(*tarefas, return_exceptions=True)

    print()

    # Escreve checkpoint final antes de guardar JSON, caso tenha parado antes do fim
    if checkpoint_committed_index >= 0 and checkpoint_committed_index < total_combinacoes - 1:
        write_dci_checkpoint(
            checkpoint_committed_index,
            combinacoes[checkpoint_committed_index],
            total_processed=checkpoint_committed_index + 1,
        )

    if stop_event.is_set() or checkpoint_committed_index < total_combinacoes - 1:
        json_path = save_dcis_json(todas_substancias)
        print(f"Progresso guardado em {json_path}")

    if checkpoint_committed_index >= total_combinacoes - 1:
        delete_dci_checkpoint()
    else:
        print("Checkpoint preservado para retomar mais tarde.")

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
