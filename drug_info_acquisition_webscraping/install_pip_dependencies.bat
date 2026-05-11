@echo off
REM Install all Python dependencies for the Infarmed scraper pipeline
echo Installing Python dependencies...

pip install playwright pdfplumber requests

REM Install Playwright browser binaries (Chromium only)
python -m playwright install chromium

echo.
echo Done. You can now run:
echo   python infarmed_scraper.py            -- Phase 1: Scrape table data
echo   python pdf_leaflet_parser.py          -- Phase 2: Extract PDF leaflet data
echo   python dart_code_generator.py         -- Phase 3: Generate Dart/JSON output
echo.
echo Or run the full pipeline at once:
echo   python run_pipeline.py