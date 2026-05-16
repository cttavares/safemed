@echo off
REM Batch file to export YOLO model to TFLite format
REM Uso: export_model.bat [nome_modelo.pt]
REM Exemplo: export_model.bat med_recog_model.pt

cd /d "%~dp0"

if "%~1"==" " (
    echo Uso: export_model.bat [nome_modelo.pt]
    echo Exemplo: export_model.bat med_recog_model.pt
    echo Padrao: med_recog_model.pt
    py -3.11 -m export_model
) else (
    py -3.11 -m export_model %~1
)

pause
