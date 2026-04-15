from pathlib import Path
import os
from ultralytics import YOLO
from roboflow import Roboflow

BASE_DIR = Path(__file__).resolve().parent          # med_recognition_train
os.chdir(BASE_DIR)                                  # opcional: força cwd do script

MODEL_PATH = BASE_DIR / "yolo11s.pt"
DATASETS_DIR = BASE_DIR / "dataset"
RUNS_DIR = BASE_DIR / "runs"

DATASETS_DIR.mkdir(parents=True, exist_ok=True)
RUNS_DIR.mkdir(parents=True, exist_ok=True)


model = YOLO(str(MODEL_PATH)) # YOLO11 SMALL model

from roboflow import Roboflow
rf = Roboflow(api_key="Jbk5UxSuXrhZbfmGrZJn")
project = rf.workspace("luss-workspace-u3jzw").project("safemed_med_recognition-zcroy")

dataset = project.version(2).download("yolov8", location=str(DATASETS_DIR / "current"))
data_yaml = Path(dataset.location) / "data.yaml"

model.train(
    data=str(data_yaml),                    # dataset path for RoboFlow
    epochs=50,                              # 50 transfer learning epochs
    imgsz=640,                              # iamge size mobnile-friendly
    patience=10,                            # early stopping
    save=True,
    device='cpu',                           # if nvidia gpu, use 0
    project=str(RUNS_DIR),                  # salva resultados dentro de med_recognition_train/runs
    # workers = 4                             # cores for loading images in paralel
)

# Export model to tflite for flutter use
model.export(format="tflite", imgsz=640, int8=True)
                
