## 📦 Roboflow 

#### Safemed med recognition 

O Dataset foi criado e anotado na plataforma Roboflow.
Modelo base YOLOv11s pré-treinado, leve e eficiente para dispositivos móveis.

O modelo foca-se na **deteção de objetos** (localização da caixa). A extração de dados textuais (Nome/Dosagem) e leitura de códigos de barras é delegada para motores de OCR e Google ML Kit, que operam apenas dentro das *Bounding Boxes* geradas por este modelo.

<https://app.roboflow.com/luss-workspace-u3jzw/safemed_med_recognition-zcroy>

## 📊 Estatísticas do Dataset
* **Total de Imagens:** 30 imagens (90 imagens apos augmentação)
* **Classes Identificadas:**
  1. `caixa` (Embalagem exterior)
  2. `blister` (Cartela de comprimidos)
  3. `frasco` (Xaropes/Líquidos)
  4. `tubo` (Pomadas/cremes)

## 🛠️ Pipeline de Pre-processing & Augmentação
Para garantir que a app funciona em condições reais (casa do utilizador), aplicámos as seguintes transformações:

### Pre-processing
* **Auto-Orient:** Garante que as fotos tiradas em modo paisagem/retrato são lidas corretamente.
* **Resize (Fit with black edges):** 640x640 pixels e com black edges para manter a proporção e não confundir o modelo com distorções.

### Augmentação (3x)
* **Blur (2.5px):** Simula a falta de foco da câmara ou mãos trémulas.
* **Brightness (+/- 25%):** Simula variações entre luz natural, lâmpadas de teto e ambientes escuros.
* **Rotation (+/- 15°):** Compensa o ângulo em que o utilizador segura o telemóvel.
* **Horizontal Flip:** Aumenta a diversidade de perspetiva dos logótipos das marcas.


## 📈 Train/Valid/Test Split
* **Treino:** 70% 
* **Validação:** 20% 
* **Teste:** 10% 