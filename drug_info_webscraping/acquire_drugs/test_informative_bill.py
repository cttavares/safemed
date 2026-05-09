"""
Script de teste para extrair e resumir Folheto Informativo por DCI.

Uso rápido:
    python test_informative_bill.py

Exemplos:
    python test_informative_bill.py --dci "Ácido acetilsalicílico"
    python test_informative_bill.py --workers 6 --table-workers 3
    python test_informative_bill.py --headed --no-export
"""

# IMPORTS
import argparse
import asyncio
import json
import time

from informative_bill_document_scrapper import extract_informative_bill_pdf_text_by_link_from_table
from table_scrapper import extract_all_tables
from utils import export_informative_bill_per_dci

# CONSTANTS
DEFAULT_DCIS = [
    "Ácido acetilsalicílico",
    "Clorofenamina + Paracetamol",
]


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Teste de extração de FI + resumo Gemini por DCI.",
    )
    parser.add_argument(
        "--dci",
        action="append",
        default=None,
        help="DCI a pesquisar (pode repetir a flag múltiplas vezes).",
    )
    parser.add_argument(
        "--workers",
        type=int,
        default=4,
        help="Número de workers para FI/Gemini.",
    )
    parser.add_argument(
        "--table-workers",
        type=int,
        default=2,
        help="Número de workers na extração de tabelas.",
    )
    parser.add_argument(
        "--headed",
        action="store_true",
        help="Executar browser com interface (headless=False).",
    )
    parser.add_argument(
        "--no-export",
        action="store_true",
        help="Não exportar JSON/CSV no fim.",
    )
    parser.add_argument(
        "--prefix",
        default="informative_bill_per_dci_test",
        help="Prefixo dos ficheiros de exportação.",
    )
    return parser.parse_args()


async def main() -> None:
    args = parse_args()
    dcis = args.dci if args.dci else DEFAULT_DCIS

    print(f"\n{'=' * 72}")
    print("TESTE: TABELA -> LINK FI -> PDF -> TEXTO -> GEMINI")
    print(f"{'=' * 72}\n")

    print(f"DCIs selecionadas ({len(dcis)}): {dcis}")
    print(f"Workers tabela: {args.table_workers} | Workers FI: {args.workers}")
    print(f"Headless: {not args.headed}\n")

    t0 = time.monotonic()

    print("1) A extrair tabela de medicamentos por DCI...")
    table_records = await extract_all_tables(dcis, max_workers=max(1, args.table_workers))
    print(f"   -> Registos de tabela: {len(table_records)}\n")

    print("2) A extrair FI e resumir com Gemini (primeiro medicamento por DCI)...")
    fi_records = await extract_informative_bill_pdf_text_by_link_from_table(
        table_records,
        headless = False,
        max_workers=max(1, args.workers),
    )
    print(f"   -> Registos FI: {len(fi_records)}\n")

    print("3) Pré-visualização (primeiros 2 resultados):")
    preview = fi_records[:2]
    print(json.dumps(preview, ensure_ascii=False, indent=2))

    if not args.no_export:
        print("\n4) A exportar resultados...")
        export_informative_bill_per_dci(fi_records, filename_prefix=args.prefix)

    elapsed = time.monotonic() - t0
    print(f"\nConcluído em {elapsed:.1f}s")


if __name__ == "__main__":
    asyncio.run(main())
