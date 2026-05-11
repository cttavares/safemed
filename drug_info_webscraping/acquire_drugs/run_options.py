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
        print(f"Passo 1. Adquirir todas as DCIs disponíveis no Infomed e exportar")
        print(f"Passo 2. Adquirir dados da tabela para um todos os DCIs")
        print(f"Passo 3. Adquirir PDFs Folheto Informativo para todos os medicamentos específicos")
        print(f"0. Voltar ao menu principal")
        choice = read_choice("\nEscolha uma opção: ", {"0", "1", "2", "3"})

        if choice == "1":
            print(f"ALL DCIs...\n")
            await extract_all_dci()
            return

        if choice == "2":
            print(f"ALL TABLES...\n")
            
            dcis = [
                "Ácido acetilsalicílico",
                "Clorofenamina + Paracetamol",
            ]
            
            results = await extract_all_tables(dcis, max_workers = 2)
            print(f"Total de rows processados: {len(results)}")
            print(results)  
            return

        if choice == "3":
            print(f"ALL PDFS...\n")
            # TODO: Implementar esta funcionalidade
            return

        if choice == "0":
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
        