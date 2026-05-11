## Ponto de Situação - Reunião de 11/05/2026

### 1. Trabalho realizado

Foi desenvolvido o módulo de web scraping do portal de pesquisa de medicamentos do **INFOMED**, com implementação em **Playwright** e técnicas de **rate limiting** e simulação de comportamento humano, de forma a reduzir o risco de bloqueio de IP e permitir um scraping mais seguro, ainda que com alguma penalização no desempenho.

Cada scraper utiliza uma implementação concorrente, com múltiplas worker threads e processamento assíncrono, para equilibrar robustez e eficiência.

### 2. Funcionamento da recolha de dados

Na caixa de pesquisa por **DCI** com autocomplete, é necessário introduzir pelo menos **3 letras** para obter a lista correspondente. O espaço de pesquisa total é de **17.576 combinações**, pelo que a lista obtida tem de ser limpa de repetidos no final do processo.

Com base em **1.686 DCI / substâncias ativas**, segundo a página de estatísticas do **INFOMED**, também recolhida pelo módulo de scrapers, são pesquisadas as tabelas por DCI e extraída a informação completa e formatada, totalizando perto de **10.000 medicamentos**.

Como ainda é necessário obter informação adicional, como indicações terapêuticas, efeitos indesejáveis, conservação e avisos críticos, é feito o scraping da página "ver mais", que contém o folheto informativo em PDF.

Recolher esta informação para perto de 10.000 medicamentos torna o processo computacionalmente muito complexo e representa um desafio de implementação.

### 3. Tratamento da informação clínica

Foi tomada a decisão de analisar estes detalhes de forma generalizada, assumindo que os medicamentos com a mesma **substância ativa** tendem a apresentar utilizações e efeitos semelhantes.

Sempre que o utilizador pesquisa estas informações na aplicação, é apresentado um **disclaimer** a indicar que a informação é generalizada, que não é **100% precisa** e que recomenda vivamente a consulta da página do **INFOMED** com o folheto informativo específico, através de um link de redirecionamento.

Como este PDF contém muita informação que, no contexto da aplicação e sobretudo em pesquisa, não é favorável, está a ser usada de forma experimental a API de IA da Google, **Gemini 2.5 Flash**, que processa o PDF e extrai a informação pedida no formato definido no prompt.

Esta abordagem torna o processo mais complexo e mais lento, mas, tendo em conta as opções disponíveis, é uma solução interessante e perfeitamente implementável.

### 4. Formato dos dados

Os dados recolhidos estão a ser produzidos em formato **JSON**, com possibilidade de exportação para **CSV** no menu de execução das web scraping tools.

### 5. Futuramente

- Trabalhar melhor o dataset do **Roboflow** para chegar a uma versão definitiva e gerar o modelo com recurso ao **Google Colab**.
- Passar os dados em **JSON** para a aplicação e prepará-la para utilização.

### 6. Decisão técnica

A aplicação pode criar uma camada de sincronização com o **JSON** e ler os dados com conversão automática de tipos e ingestão de dados por **bulk insert**. Em vez de inserir um registo de cada vez durante a inicialização da aplicação, esta abordagem usa **transactions** e **batch inserts** para inserir cerca de **1000 registos** por transação.

No entanto, utilizar um dump **.sqlite** pré-gerado é mais eficiente para este grande volume de dados estáticos. Retira a necessidade de loadings associados à ingestão de dados e garante a integridade, com maiores possibilidades de manipulação local.

Neste momento, a decisão é avançar com a **pre-população da base de dados** e com o dump **.sqlite** gerado através de um script Python, visto que a aplicação tem foco em **offline** e **estabilidade**, pelo que os dados são maioritariamente estáticos e esta implementação faz mais sentido.

A principal desvantagem é que pode ser mais complexo gerir versões e migrations se a estrutura das tabelas mudar. Ainda assim, a informação nunca se perde, porque o JSON fica guardado na pasta dedicada ao web scraping no repositório.

