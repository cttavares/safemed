@echo off
REM Batch file to export YOLO model to TFLite format
REM Uso: export_model.bat [nome_modelo.pt]
REM Exemplo: export_model.bat med_recog_model.pt

cd /d "%~dp0"

if "%~1"==" " (
    echo Uso: export_model.bat [nome_modelo.pt]
    echo Exemplo: export_model.bat med_recog_model.pt
    echo Padrao: med_recog_model.pt
    python export_model.py
) else (
    python export_model.py %~1
)

pause
