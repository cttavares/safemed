## Ponto de Situação - 11/05/2026

### 1. Gestão de Perfis de Utilizador

- Implementados **múltiplos perfis** de utente com nome, idade, sexo, foto e categorização automática (adulto, criança, idoso) com base na idade.
- Cada perfil regista condições clínicas relevantes: **doença renal**, **doença hepática**, **diabetes** e **hipertensão**.
- Suporte a **gravidez** (apenas para perfis femininos), **alergias** e **restrições médicas** como listas editáveis.
- Os perfis são persistidos localmente em JSON via `ProfileStore` e carregados no arranque da app.
- Interface com ecrã de lista, seleção, criação e edição completa do perfil (`profile_list_screen`, `profile_form_screen`, `profile_detail_screen`).
- Cada perfil tem um **tom de alarme** configurável (padrão ou personalizado com URI do dispositivo).

---

### 2. Avisos por Medicação (Motor de Risco)

O motor de análise (`risk_engine.dart`) cruza o plano de medicação ativo com o perfil do utilizador e gera alertas classificados por severidade: **Critical**, **High**, **Moderate** e **Info**.

As categorias de verificação implementadas são:

- **Condições clínicas** — NSAIDs em doença renal, paracetamol/estatinas em doença hepática, corticosteroides em diabetes, descongestionantes/NSAIDs em hipertensão.
- **Gravidez** — Varfarina, isotretinoína, metotrexato, NSAIDs no 3.º trimestre, tetraciclinas, SSRIs.
- **Idade** — Aspirina e fluoroquinolonas em crianças; benzodiazepinas, TCAs e digoxina em idosos (critérios de Beers).
- **Alergias** — Correspondência direta pelo nome e reatividade cruzada para grupos: penicilinas/cefalosporinas, sulfamidas, NSAIDs.
- **Interações medicamento-medicamento** — 13 regras implementadas, incluindo: anticoagulante + NSAID, síndrome serotoninérgica (SSRI + tramadol, MAOI + serotonérgico), inibidor PDE5 + nitrato, estatina + inibidor CYP3A4, entre outras.

---

### 3. Alertas e Histórico de Medicação

- **Alertas de toma** implementados como alarmes nativos Android com `AlarmManager` via `medication_alarm_scheduler.dart`.
- Os alarmes disparam uma `AlarmActivity` que apresenta um ecrã em fullscreen mesmo com o telemóvel bloqueado, com som e vibração.
- O utilizador pode **confirmar a toma** ou **adiar o alarme** diretamente no ecrã do alarme.
- Cada confirmação regista uma entrada no **histórico de medicação** (`MedicationHistoryStore`) com timestamp, nome do medicamento, dosagem e estado (tomado/ignorado).
- O histórico é visualizável por perfil com filtragem por período e estatísticas de adesão (`medication_history_screen.dart`).
- O ecrã de alertas (`alerts_screen.dart`) lista os alarmes futuros agendados para o perfil ativo.

---

### 4. Condições e Alergias

- As **condições clínicas** (doença renal, hepática, diabetes, hipertensão) são definidas no perfil como *flags* booleanas.
- As **alergias** são uma lista livre de texto editável, sem ontologia fixa — o motor de risco faz correspondência por substring e grupos de reatividade cruzada.
- As **restrições médicas** são uma lista separada, também de texto livre.
- Toda esta informação é usada em tempo real pelo motor de risco ao analisar qualquer plano de medicação.
- A interface de criação/edição do perfil permite gerir estes campos diretamente (`profile_form_screen.dart`).

---

### 5. Web Scraping — Aquisição de Dados do Infarmed

Pipeline completo implementado em Python (Playwright + Gemini) em `drug_info_webscraping/`, com 4 passos sequenciais:

#### Passo 1 — DCIs (`dci_scrapper.py`)
- 6 workers paralelos testam as **17.576 combinações de 3 letras** no autocomplete de Substâncias Ativas do portal público do Infarmed.
- Resultado exportado para `outputs/dcis_infomed.json`.

#### Passo 2 — Tabela de Medicamentos (`table_scrapper.py`)
- Para cada DCI, extrai a tabela de medicamentos: nome comercial, forma farmacêutica, dosagem, CNPEM, preços (PVP, notificado, utente, pensionista) e link de detalhe.
- 6 workers paralelos. Resultado exportado para `outputs/medicamentos_infomed.json`.

#### Passo 3 — Folheto Informativo + Gemini (`informative_bill_document_scrapper.py`)
- Para o primeiro medicamento de cada DCI, acede à página de detalhe do Infomed, faz o download do PDF do Folheto Informativo via POST do formulário JSF e extrai o texto com `pypdf`.
- O texto é enviado para o **Gemini 2.5 Flash** que devolve um resumo estruturado: indicações, efeitos indesejáveis (frequentes/outros), conservação e aviso crítico.
- Requer `GEMINI_API_KEY` no ficheiro `acquire_drugs/.env`.

#### Passo 4 — Exportação para Flutter (`flutter_exporter.py`)
- Converte os outputs dos passos 2 e 3 para o schema esperado pelo `InfarmedMedicationService` do Flutter.
- Escreve diretamente em `assets/medications_infarmed.json`.
- A app carrega este ficheiro no arranque e disponibiliza pesquisa por nome comercial, DCI e CNPEM.

#### Execução
```
drug_info_webscraping/webscraping_tools.bat → Opção 1 → Protocolo Completo → Passos 1 a 4
```

#### Fase futura
- Integração com **Drugs.com** para enriquecer a base de dados de interações medicamentosas (opção 2 no menu já preparada).
