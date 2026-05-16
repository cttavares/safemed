@echo off
REM python 3.11
REM Playwright

py -3.11 -m pip install playwright asyncio google-genai pypdf pyPDF2 pandas
py -3.11 -m playwright install chromium