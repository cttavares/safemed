## Ponto de Situação - Reunião de 30/04/2026

### 1. Desenvolvimento Mobile (Flutter e Visão Computacional)

- A funcionalidade **Medication Explorer** encontra-se em desenvolvimento, com integração do módulo `flutter_vision`.
- O modelo utilizado é o **YOLO11s** exportado para **TFLite INT8**, uma escolha técnica orientada para melhor desempenho e maior taxa de FPS em dispositivos móveis, que reduz o consumo de recursos no telemóvel. Ainda assim, o modelo está com baixa precisão pelo que não consegue identificar os medicamentos de forma consistente.
- Foi identificada a necessidade de reforçar a precisão do modelo. Neste momento, está a ser consolidado um novo dataset mais robusto através da fusão de vários conjuntos de datasets públicos do **Roboflow Universe**.

### 2. Infraestrutura de Treino (Google Colab)

- O pipeline de treino está a ser migrado para o **Google Colab**, de forma a acelerar o processo e aproveitar GPU na geração de novas versões do modelo.
- Foi realizado um teste com um dataset de **2.500 imagens** durante **60 epochs**, concluído em **2h10min**, validando a eficiência deste workflow.

### 3. Aquisição e Engenharia de Dados (Web Scraping)

Na ausência de uma API oficial no portal **INFOMED**, foi definida uma estratégia de extração de dados com **Playwright em Python**.

#### 3.1 Otimização da Pesquisa

- A pesquisa por número de registo de 7 dígitos foi descartada, uma vez que cobrir mais de **10 milhões de combinações** seria computacionalmente inviável.
- Em alternativa, a extração será feita através do autocomplete de **Substâncias Ativas (DCI)**, reduzindo o espaço de pesquisa para cerca de **17 mil combinações**.

#### 3.2 Estratégia de Scraping

- A implementação com Playwright incluirá técnicas de **rate limiting** e **simulação de comportamento humano**.
- Serão aplicados atrasos aleatórios e cabeçalhos de navegação para mitigar o risco de bloqueio de IP pelo servidor.

#### 3.3 Pipeline de Inteligência de Dados

- Extração da lista de DCIs e metadados da tabela INFOMED, com foco em **1.683 substâncias** e **10.384 medicamentos**.
- Download automático dos **Folhetos Informativos em PDF**.
- Processamento com LLM para converter PDFs em texto estruturado e extrair automaticamente:
	- indicações terapêuticas;
	- efeitos indesejáveis;
	- modo de conservação.

#### 3.4 Fase Futura

- Avaliação de integração com fontes externas, como o **Drugs.com**, para expandir a base de dados de interações medicamentosas.
