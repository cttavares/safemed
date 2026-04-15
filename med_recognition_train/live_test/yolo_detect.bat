@echo off
REM python 3.11
cd /d "%~dp0\..\.."

set MODEL_PATH=%~dp0best.pt
set SOURCE=usb0
set RESOLUTION=640x480

echo MODEL_PATH=%MODEL_PATH%

if exist "%MODEL_PATH%" (
    echo [OK] Modelo encontrado.
) else (
    echo [ERRO] Modelo nao encontrado em: "%MODEL_PATH%"
    pause
    exit /b 1
)

py -3.11 -m med_recognition_train.live_test.check_camera_usb
py -3.11 -m med_recognition_train.live_test.yolo_detect.py --model %MODEL_PATH% --source %SOURCE% --resolution %RESOLUTION%