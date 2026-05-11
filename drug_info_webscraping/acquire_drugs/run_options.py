try:
    from .dci_scrapper import (
        get_statistics,
        extract_all_dci,
        extract_dci_for_term,
    )
    from .table_scrapper import (
        extract_table_from_dci,
        extract_all_tables
    )
    from .informative_bill_document_scrapper import (
        extract_informative_bill_pdf_text_by_link_from_table,
    )
    from .utils import (
        export_dcis,
        export_tables,
        export_informative_bill_per_dci,
        import_dcis_from_json,
        import_table_from_json,
        OUTPUT_DIR,
    )
    from .flutter_exporter import export_to_flutter
except Exception:
    from dci_scrapper import (
        get_statistics,
        extract_all_dci,
        extract_dci_for_term,
    )
    from table_scrapper import (
        extract_table_from_dci,
        extract_all_tables
    )
    from informative_bill_document_scrapper import (
        extract_informative_bill_pdf_text_by_link_from_table,
    )
    from utils import (
        export_dcis,
        export_tables,
        export_informative_bill_per_dci,
        import_dcis_from_json,
        import_table_from_json,
        OUTPUT_DIR,
    )
    from flutter_exporter import export_to_flutter


def read_choice(prompt: str, valid_options: set[str]) -> str:
    while True:
        choice = input(prompt).strip()
        if choice in valid_options:
            return choice
        print("    Opção inválida. Tenta novamente.")


def choose_example_or_custom(example: str) -> str:
    print(f"    Escolha uma opção:")
    print(f"    1. Usar exemplo pré-definido (ex: '{example}')")
    print(f"    2. Digitar um termo personalizado\n")
    choice = read_choice("    Opção (1 ou 2): ", {"1", "2"})
    if choice == "1":
        return example
    else:
        term = input("    Digita o termo: ").strip()
        return term


async def main_menu():
    while True:
        print(f"{'='*38}\nSCRAPING DE MEDICAMENTOS SITE INFARMED\n{'='*38}\n")
        print(f"1. Executar protocolo completo")
        print(f"2. Testar funções separadas")
        print(f"3. Ver estatísticas atuais da base de dados do Infomed")
        print(f"0. Sair")
        choice = read_choice("\nEscolha uma opção: ", {"0", "1", "2", "3"})

        if choice == "1":
            print(f"Executar protocolo completo...\n")
            await protocol_menu()
        elif choice == "2":
            print(f"Testar funções separadas...\n")
            await test_menu()
        elif choice == "3":
            print(f"Ver estatísticas atuais da base de dados do Infomed...\n")
            statistics = await get_statistics()
            print(f"Número total de DCIs: {statistics[0]}")
            print(f"Número total de medicamentos: {statistics[1]}")
            print(f"Número total de apresentações: {statistics[2]}")
            print(f"Data da última atualização: {statistics[3]}\n")
        elif choice == "0":
            print(f"A sair...\n")
            return

async def protocol_menu():
    while True:
        print(f"\n{'='*50}")
        print(f"Passo 1. Adquirir DCIs do Infomed e exportar (dcis_infomed.json)")
        print(f"Passo 2. Adquirir tabela de medicamentos para todos os DCIs")
        print(f"Passo 3. Adquirir PDFs Folheto Informativo e resumir com Gemini")
        print(f"Passo 4. Exportar para Flutter (assets/medications_infarmed.json)")
        print(f"0. Voltar ao menu principal")
        choice = read_choice("\nEscolha uma opção: ", {"0", "1", "2", "3", "4"})

        if choice == "1":
            print(f"\n[PASSO 1] A adquirir todas as DCIs...\n")
            dcis = await extract_all_dci()
            print(f"\n  -> {len(dcis)} DCIs encontradas.")
            try:
                export_dcis(dcis, csv_option=True)
            except Exception as e:
                print(f"  [ERRO] Exportação de DCIs: {e}")

        elif choice == "2":
            print(f"\n[PASSO 2] A carregar DCIs do ficheiro exportado...")
            try:
                dcis = import_dcis_from_json(OUTPUT_DIR / "dcis_infomed.json")
            except FileNotFoundError:
                print("  [AVISO] Ficheiro dcis_infomed.json não encontrado. Executa o Passo 1 primeiro.")
                continue
            except Exception as e:
                print(f"  [ERRO] {e}")
                continue

            print(f"  -> {len(dcis)} DCIs carregadas. A extrair tabelas...\n")
            records = await extract_all_tables(dcis, max_workers=6)
            print(f"\n  -> {len(records)} registos extraídos.")
            try:
                export_tables(records, csv_option=True)
            except Exception as e:
                print(f"  [ERRO] Exportação de tabelas: {e}")

        elif choice == "3":
            print(f"\n[PASSO 3] A carregar tabela de medicamentos do ficheiro exportado...")
            try:
                table_records = import_table_from_json(OUTPUT_DIR / "medicamentos_infomed.json")
            except FileNotFoundError:
                print("  [AVISO] Ficheiro medicamentos_infomed.json não encontrado. Executa o Passo 2 primeiro.")
                continue
            except Exception as e:
                print(f"  [ERRO] {e}")
                continue

            print(f"  -> {len(table_records)} registos carregados. A extrair Folheto Informativo e resumir com Gemini...\n")
            fi_records = await extract_informative_bill_pdf_text_by_link_from_table(
                table_records,
                headless=True,
                max_workers=4,
            )
            print(f"\n  -> {len(fi_records)} resumos gerados.")
            try:
                export_informative_bill_per_dci(
                    fi_records,
                    filename_prefix="informative_bill_per_dci",
                    csv_option=True,
                )
            except Exception as e:
                print(f"  [ERRO] Exportação FI: {e}")

        elif choice == "4":
            print(f"\n[PASSO 4] A gerar assets/medications_infarmed.json para Flutter...")
            try:
                table_records = import_table_from_json(OUTPUT_DIR / "medicamentos_infomed.json")
            except FileNotFoundError:
                print("  [AVISO] Ficheiro medicamentos_infomed.json não encontrado. Executa o Passo 2 primeiro.")
                continue
            except Exception as e:
                print(f"  [ERRO] ao carregar tabela: {e}")
                continue

            fi_records = []
            fi_path = OUTPUT_DIR / "informative_bill_per_dci.json"
            if fi_path.exists():
                import json
                with fi_path.open(encoding="utf-8") as f:
                    data = json.load(f)
                fi_records = data.get("records", [])
                print(f"  -> {len(fi_records)} resumos Gemini carregados.")
            else:
                print("  [AVISO] informative_bill_per_dci.json não encontrado — exportação sem dados clínicos do Gemini.")

            try:
                count = export_to_flutter(table_records, fi_records)
                print(f"  -> Flutter asset gerado com {count} medicamentos.")
            except Exception as e:
                print(f"  [ERRO] {e}")

        elif choice == "0":
            return

async def test_menu():
    while True:
        print(f"1. Testar Autocomplete de DCIs com combinação de 3 letras à escolha (ex: 'aci')")
        print(f"2. Adquirir dados da tabela para um DCI específico (ex: 'Ácido acetilsalicílico')")
        print(f"3. Adquirir PDF Folheto Informativo para um medicamento específico (ex: 'Ácido Acetilsalicílico Lumec')")
        print(f"0. Voltar ao menu principal")
        choice = read_choice("\nEscolha uma opção: ", {"0", "1", "2", "3"})

        if choice == "1":
            print(f"TESTAR AUTOCOMPLETE DCIs...\n")

            term = choose_example_or_custom("aci")
            dcis = list(await extract_dci_for_term(term))
            print(f"Total de substâncias únicas encontradas para '{term}': {len(dcis)}")
            print(dcis)
            return

        if choice == "2":
            print(f"ADQUIRIR DADOS DA TABELA...\n")
            term = choose_example_or_custom("Ácido acetilsalicílico")
            records = await extract_table_from_dci(term)
            print(f"Total de registros encontrados para '{term}': {len(records)}")
            for rec in records:
                print(rec)
            return

        if choice == "3":
            print(f"ADQUIRIR PDF FOLHETO INFORMATIVO...\n")
            print(f"TODO: Implementar esta funcionalidade")
            return

        if choice == "0":
            return
        