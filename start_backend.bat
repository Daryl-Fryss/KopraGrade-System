@echo off
REM Starts the KopraGrade API so phones on the same Wi-Fi can reach it.
cd /d "%~dp0backend" || exit /b 1
call .venv\Scripts\activate
uvicorn app.main:app --host 0.0.0.0 --port 8000
