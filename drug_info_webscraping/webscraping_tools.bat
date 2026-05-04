@echo off

:menu
cls
echo ===========================================
echo            WEBSCRAPING TOOLS
echo ===========================================
echo.
echo 1. Infomed Drug Info Acquisition
echo 2. Drugs.com Drug Interaction Info Acquisition
echo 0. Exit
echo.
echo ===========================================

set /p choice="Select an option: "

if "%choice%"=="1" (
    cls
    echo Running Infomed Drug Info Acquisition...
    echo.
    py -3.11 -m acquire_drugs.main
    pause
    goto menu

) else if "%choice%"=="2" (
    cls
    echo Running Drugs.com Drug Interaction Info Acquisition...
    echo.
    REM Substitui pelo comando real do scrapper da drugs.com
    pause
    goto menu
    
) else if "%choice%"=="0" (
    echo Exiting...
    timeout /t 1 >nul
    exit /b 0

) else (
    echo.
    echo [!] Invalid option. Please select 1, 2, or 0.
    timeout /t 2 /nobreak >nul
    goto menu
)