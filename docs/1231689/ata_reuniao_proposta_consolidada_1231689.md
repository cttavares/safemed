# Safemed - Ata de Reunião (Propostas DEI)

## Título
```
Aquisição inteligente de informação e identificação automática de medicamentos
```

## Motivação
```
A crescente complexidade terapêutica e a frequência de erros de medicação representam
um desafio significativo para a segurança do doente. Muitos utentes, especialmente os
polimedicados, desconhecem as interações, contraindicações ou riscos associados aos fár-
macos prescritos. A SafeMed surge como resposta a esta lacuna, combinando informação
científica fiável com uma interface acessível, inspirada em iniciativas de referência inter-
nacionais que oferecem avaliação de risco simplificada e compreensível.
```

## Descrição
```
O SafeMed é uma aplicação móvel multiplataforma concebida como ferramenta digital de apoio à gestão segura da medicação. A solução diferencia-se pela utilização de técnicas de Visão Computacional e OCR para a aquisição inteligente de informação que permite identificar medicamentos através da fotografia da embalagem (aspeto geral da caixa, etiquetas e código de barras) ou da leitura automática de receitas médicas em papel ou em documentos digitais como PDF. 
A aplicação integra um motor de decisão baseado em lógica determinística que cruza os dados dos fármacos com o perfil clínico do utilizador (o que inclui patologias, alergias, estado fisiológico e outros) para gerar alertas de risco personalizados.
Além da análise de segurança, oferece funcionalidades de gestão de adesão, como planos de toma personalizados, notificações configuráveis e um registo de tomas, com suporte para múltiplos perfis, permitindo a gestão da medicação de membros do agregado familiar (ex: crianças ou idosos).
```

## Objetivos
```
Promover a literacia em saúde e a segurança do utente.

Avaliar a adequação das prescrições às condições clínicas individuais.

Detetar e comunicar possíveis interações ou contraindicações.

Fornecer informação explicativa e educativa, nunca substitutiva do parecer médico.
```

------
------

## Solução Preconizada
#### Qual a (proposta de) solução preconizada para resolver o problema e atingir o(s) objetivo(s)?
```
1 - Módulo de Aquisição Inteligente de Dados:  Desenvolvimento de uma funcionalidade de identificação de medicamentos, recorrendo a técnicas de visão computacional para deteção de embalagens de medicamentos, através da forma das caixas, leitura de etiquetas com nomes comerciais e leitura de códigos de barras. Inclui-se ainda a pesquisa de medicamentos por múltiplos modos de entrada, permitindo a introdução de sintomas ou nomes de medicamentos através de texto ou comandos de voz. Desenvolvimento de uma funcionalidade para a introdução e gestão de prescrições médicas, suportando tanto a introdução manual por escrito como a leitura automática de receitas médicas, através de reconhecimento ótico de caracteres (OCR).

2 - Gestão Multi-Perfil:
Desenvolvimento de uma funcionalidade de gestão de perfis de utilizador, possibilitando o registo estruturado de condições de saúde específicas, como patologias, alergias, restrições médicas e outras informações relevantes para a avaliação terapêutica. Esta funcionalidade deve suportar múltiplos perfis por dispositivo/conta, permitindo a alternância entre perfis (ex.: adulto, criança, idoso) e garantindo que medicação, alertas e histórico ficam associados ao perfil correto.

3 - Motor de Avaliação de Risco Clínico: Utilização de um sistema baseado em lógica determinística e regras clínicas explícitas. Este motor cruza a medicação introduzida com o perfil clínico personalizado do utilizador (idade, peso, patologias, alergias e estado fisiológico como gravidez) para detetar interações, duplicações ou contraindicações.

4 - Sistema de Gestão de Adesão e Notificações:
Desenvolvimento de funcionalidades de planeamento e acompanhamento da toma de medicamentos, com definição de planos de toma personalizados, incluindo horários, doses e duração do tratamento, assim como notificações/alertas às horas especificas da toma e histórico terapêutico de tomas, apoiando o acompanhamento da adesão ao plano definido.

5 - Curadoria Evolutiva da Base de Dados de Medicamentos:
Desenvolvimento de um repositório inicial simplificado para testes do protótipo, evoluindo para a implementação de um mecanismo de web scraping focado na extração automatizada e periódica de dados oficiais a partir de fontes de referência nacionais, como o Infarmed (Infomed), garantindo a integridade e atualização da informação.

6 - Interface, Experiência de Utilizador e Comunicação Educativa:
Disponibilização de um "Modo por Órgãos", que permite a seleção visual de sistemas do corpo para identificar patologias de forma intuitiva, facilitando a interação para utilizadores com menor literacia digital.
Apresentação de relatórios de segurança com classificação de risco por cores (verde, amarelo, laranja, vermelho) e explicações em linguagem simples, de forma a promover a literacia sem substituir o parecer médico.
```

## Validação preconizada
#### Qual a proposta de validação da solução a desenvolver?
```
1 - Validação Técnica dos Módulos de Aquisição:
Testes de precisão e desempenho dos módulos de Visão Computacional e OCR para garantir a correta identificação de embalagens e extração fidedigna de dados de receitas.

2 - Validação Clínica do Motor de Avaliação de Risco:
Comparação dos alertas gerados pelo motor de decisão com avaliações de especialistas clínicos, utilizando casos de teste baseados em perfis clínicos reais e cenários de medicação complexa.

3 - Validação de Usabilidade e Acessibilidade:
Avaliação da interface com utilizadores reais (ex: idosos, doentes crónicos), utilizando métricas de usabilidade e feedback qualitativo para garantir que a aplicação é intuitiva e acessível a um público diversificado.

4 - Testes em Ambiente Real:
Avaliação do impacto da aplicação na literacia em saúde dos utentes e na redução de erros de medicação evitáveis.

5 - Auditoria de Segurança:
Verificação da conformidade com o RGPD, assegurando a eficácia do processamento local e da encriptação na proteção de dados sensíveis.

```

## Planeamento
#### E.g. nome da tarefa, início e fim.
```
14 semanas (02/03/2026 - 07/06/2026)

1ª semana (02/03/2026 - 08/03/2026) - 
Identificação das tecnologias que vamos usar: 02/03/2026; 
Pesquisar aplicações semelhantes já implementadas e em uso: 03/03/2026 - 04/03/2026; 
Pesquisar os melhores métodos e ideias sobre a implementação da aplicação: 05/03/2026 - 06/03/2026.

2ª semana (09/03/2026 - 15/03/2026) - 
Engenharia de Software: 09/03/2026 - 15/03/2026.

3ª semana (16/03/2026 - 22/03/2026) - 
Engenharia de Software: 16/03/2026 - 17/03/2026;
Desenvolvimento: 17/03/2026 - 20/03/2026.

4ª - 6ª semanas (23/03/2026 - 06/04/2026) - 
Testes Unitários: 23/03/2026 - 26/03/2026;
Desenvolvimento: 23/03/2026 - 06/04/2026.

7ª semana (06/04/2026 - 12/04/2026) - 
Testes de Integração: 06/04/2026 - 09/04/2026;
Revisão Intermédia do Projeto, avaliação de progresso e ajustes para as semanas finais: 10/04/2026 - 12/04/2026.

8ª - 12ª semanas (13/04/2026 - 24/05/2026) -
Desenvolvimento: 13/04/2026 - 24/05/2026.
Testes finais: 22/05/2026 - 24/05/2026.

13ª - 14ª semana (25/05/2026 - 07/06/2026) - 
Finalização, organizar e garantir a integridade do projeto: 27/05/2026 - 07/06/2026.
Preparação da documentação final e apresentação: 30/05/2026 - 07/06/2026.
```

## Descrição de estágio
#### (e.g. Duração, Horário, Local)
#### (NB: estágio pode existir quando o projeto é desenvolvido no âmbito duma organização com quem o estudante não tem um contrato de trabalho)
```

```