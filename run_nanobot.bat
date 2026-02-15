@echo off
SETLOCAL
SET "PYTHONUTF8=1"
SET "VENV_PATH=%~dp0.venv"

echo 🐈 Starting Nanobot Gateway...
"%VENV_PATH%\Scripts\python.exe" -m nanobot gateway

if %ERRORLEVEL% neq 0 (
    echo.
    echo [ERROR] Nanobot failed to start.
    pause
)
ENDLOCAL
