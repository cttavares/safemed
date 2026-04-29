from pathlib import Path
import os
import sys
from ultralytics import YOLO

BASE_DIR = Path(__file__).resolve().parent          # med_recognition_train
os.chdir(BASE_DIR)                                  # força cwd do script

# Recebe nome do modelo como argumento, com padrão
model_name = sys.argv[1] if len(sys.argv) > 1 else "med_recog_model.pt"
MODEL_PATH = BASE_DIR / model_name
model = YOLO(str(MODEL_PATH)) # YOLO11 SMALL model

# Export model to tflite for flutter use
print("Exporting model to TFLite format...")
model.export(format="tflite", imgsz=640, int8=True)
print("Exportation completed!")
