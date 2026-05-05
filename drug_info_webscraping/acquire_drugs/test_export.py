"""
Script de teste para extrair DCIs, tabelas e exportar para JSON/CSV
"""
import asyncio
from table_scrapper import extract_all_tables, export_dcis, export_tables


async def main():
    # Lista de DCIs para testar
    dcis = [
        "ácido acetilsalisílico",
        "Clorofenamina + Paracetamol",
    ]
    
    print(f"\n{'='*60}")
    print(f"TESTE DE EXTRAÇÃO E EXPORTAÇÃO")
    print(f"{'='*60}\n")
    
    print(f"1. Extraindo tabelas para {len(dcis)} DCIs...\n")
    records = await extract_all_tables(dcis, max_workers=2)
    
    print(f"\n\n2. Exportando DCIs...\n")
    try:
        export_dcis(dcis, filename_prefix="dcis_teste")
    except Exception as e:
        print(f"✗ Erro ao exportar DCIs: {e}")
    
    print(f"\n3. Exportando tabelas de medicamentos...\n")
    try:
        export_tables(records, filename_prefix="medicamentos_teste")
    except Exception as e:
        print(f"✗ Erro ao exportar tabelas: {e}")
    
    print(f"\n{'='*60}")
    print(f"Resumo: {len(records)} medicamentos extraídos de {len(dcis)} DCIs")
    print(f"{'='*60}\n")


if __name__ == "__main__":
    asyncio.run(main())
