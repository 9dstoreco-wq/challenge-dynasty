@echo off
setlocal
cd /d "%~dp0"
where powershell >nul 2>&1
if errorlevel 1 (
  echo PowerShell no esta disponible.
  pause
  exit /b 1
)
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0FINALIZAR_WINDOWS.ps1"
if errorlevel 1 (
  echo.
  echo LA FINALIZACION NO PASO. Revisa el mensaje anterior.
  pause
  exit /b 1
)
echo.
echo CHALLENGE DYNASTY FINALIZADO CORRECTAMENTE.
pause
