# ExmplosInteracoes

Este ficheiro resume exemplos de testes para os avisos por cor no SafeMed.

Cores usadas:
- Vermelho = risco alto
- Amarelo = risco medio
- Verde = risco baixo

## 1) Alergias

### Vermelho (alto)
- Perfil com alergia: `Penicilina`
- Medicamento escolhido: `Amoxicilina` ou `Ampicilina Labesfal`
- Resultado esperado: alerta vermelho com mensagem de que o utilizador nao pode tomar devido a alergia `Penicilina`.

- Perfil com alergia: `Sulfonamidas`
- Medicamento escolhido: `Bactrim Forte` (Sulfametoxazol + Trimetoprim)
- Resultado esperado: alerta vermelho.

### Amarelo (medio)
- No sistema atual, alergia compativel e sempre tratada como risco alto.
- Nao existe regra de alergia em amarelo nesta versao.

### Verde (baixo)
- Perfil com alergia: `Penicilina`
- Medicamento escolhido: `Omeprazol`
- Resultado esperado: sem alerta de alergia (baixo risco no contexto de alergia).

## 2) Interacoes medicamentosas

### Vermelho (alto)
- No mesmo plano, adicionar:
  - `Ben-u-ron` (Paracetamol)
  - `Panadol` (Paracetamol)
- Resultado esperado: duplicacao de substancia ativa -> risco alto (vermelho).

- No mesmo plano, adicionar:
  - `Varfine` (Varfarina)
  - `Aspirina` (Acido Acetilsalicilico)
- Resultado esperado: risco alto de interação/hemorragia -> vermelho.

### Amarelo (medio)
- No mesmo plano, adicionar:
  - `Brufen` (Ibuprofeno)
  - `Aspirina` (Acido Acetilsalicilico)
- Resultado esperado: possivel interacao medicamentosa -> risco medio (amarelo).

- No mesmo plano, adicionar:
  - `Lasix` (Furosemida)
  - `Zestril` (Lisinopril)
- Resultado esperado: possivel interação de monitorização -> risco medio (amarelo).

### Verde (baixo)
- No mesmo plano, adicionar:
  - `Omeprazol`
  - `Centrum`
- Resultado esperado: sem interacao relevante -> risco baixo (verde).

- No mesmo plano, adicionar:
  - `Eutirox`
  - `Bisolvon`
- Resultado esperado: sem interacao relevante -> risco baixo (verde).

## 3) Gravidez (escala FDA)

Para estes testes, o perfil deve ser:
- Sexo: `Feminino`
- Gravida: `Sim`

### Vermelho (alto)
- Medicamento: `Roacutan` (Isotretinoina) ou `Talidomida Generis`
- Categoria FDA: `X`
- Resultado esperado: alerta vermelho de contraindicado na gravidez.

- Medicamento: `Varfine` (Varfarina)
- Categoria FDA: `X`
- Resultado esperado: alerta vermelho.

### Amarelo (medio)
- Medicamento: `Brufen` (Ibuprofeno)
- Categoria FDA: `C`
- Resultado esperado: aviso em amarelo (avaliar risco/beneficio).

- Medicamento: `Amlodipina Generis`
- Categoria FDA: `C`
- Resultado esperado: aviso em amarelo.

### Verde (baixo)
- Medicamento: `Bisolvon` (FDA A) ou `Ben-u-ron` (FDA B)
- Resultado esperado: aviso em verde/verde-claro conforme categoria FDA.

- Medicamento: `Eutirox` (FDA A)
- Resultado esperado: aviso verde.

## 4) Condicoes clinicas do perfil

### Vermelho (alto)
- Perfil com condição: `Hipertensão`
- Medicamento: `Actifed` (Pseudoefedrina)
- Resultado esperado: alerta vermelho por condição incompatível.

- Perfil com condição: `Diabetes`
- Medicamento: `Prednisona Teva` (Prednisolona)
- Resultado esperado: alerta vermelho por condição incompatível.

### Amarelo (medio)
- Perfil com restrição: `Necessidade de administração com alimento`
- Medicamento: `Brufen`
- Resultado esperado: aviso amarelo de restrição prática.

- Perfil com restrição: `Evitar sedação (risco de quedas)`
- Medicamento: `Valium`
- Resultado esperado: aviso amarelo.

### Verde (baixo)
- Perfil com condição: `Hipertensão`
- Medicamento: `Omeprazol`
- Resultado esperado: sem conflito por condição -> verde.

- Perfil com restrição: `Disfagia (dificuldade de deglutição)`
- Medicamento: `Bisolvon` (xarope)
- Resultado esperado: sem conflito por forma farmacêutica -> verde.

## 5) Checklist rapido de validacao

1. Criar/editar perfil e escolher alergias na lista.
2. Se for perfil feminino, ativar opcao gravida.
3. Criar plano e abrir selecao de medicamentos.
4. Verificar chips de risco por cor na lista.
5. Selecionar medicamento e validar mensagem detalhada no dialogo.
6. Adicionar combinacoes no mesmo plano para testar interacoes (vermelho/amarelo/verde).
7. Validar cenarios de condicoes clinicas e restricoes praticas.
