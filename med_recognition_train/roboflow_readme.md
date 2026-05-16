## 📦 Roboflow and GoogleCollab

#### Safemed med recognition 

O Dataset foi criado e anotado na plataforma Roboflow.
Modelo base YOLOv11s pré-treinado, leve e eficiente para dispositivos móveis.

O modelo foca-se na **deteção de objetos** (localização da caixa). A extração de dados textuais (Nome/Dosagem) e leitura de códigos de barras é delegada para motores de OCR e Google ML Kit, que operam apenas dentro das *Bounding Boxes* geradas por este modelo.

<https://app.roboflow.com/luss-workspace-u3jzw/safemed_med_recognition-zcroy>

É recomendado usar o Google Coolab com GPU Tesla T4 para treinar o modelo para melhores tempos de treino e poupar recursos. O notebook de treino está disponível aqui:

<https://colab.research.google.com/drive/1052Gm3gbpe4vTrlUioCXPMUyKHFLhElh?usp=sharing>

O modelo em formato .pt do med_recognition_model yolo11s pode ser encontrado aqui:
`med_recognition_train/med_recognition_model.pt`

O modelo exportado para formato TensorFlow Lite usado no flutter pode ser encontrado aqui (versões INT8, FLOAT16 e FLOAT32):
`assets/yolo11s/med_recog_best_int8.tflite`

## 📊 Estatísticas do Dataset
* **Total de Imagens:** 1233 imagens dataset (2022 imagens após augmentação 2x)
* **Classes Identificadas:**
  1. `blister` (Cartela de comprimidos)
  2. `box` (Embalagem exterior)

## 🛠️ Pipeline de Pre-processing & Augmentação
Para garantir que a app funciona em condições reais (casa do utilizador), aplicámos as seguintes transformações:

### Pre-processing
* **Auto-Orient:** Garante que as fotos tiradas em modo paisagem/retrato são lidas corretamente.
* **Resize (Stretch to 640x640 ):** 640x640 pixels e, como as imagens estão todas em formato 1:1, não há distorção.

### Augmentação (3x)
* **Blur (1px):** Simula a falta de foco da câmara ou mãos trémulas.
* **Brightness (+/- 20%):** Simula variações entre luz natural, lâmpadas de teto e ambientes escuros.
* **Rotation (+/- 15°):** Compensa o ângulo em que o utilizador segura o telemóvel.


## 📈 Train/Valid/Test Split
* **Treino:** 78% 
* **Validação:** 12% 
* **Teste:** 10% 