@echo off
setlocal
cd /d "%~dp0"
echo.
echo CHALLENGE DYNASTY - INSTALACION
if not exist package.json (
  echo No encuentro package.json.
  pause
  exit /b 1
)
where node >nul 2>&1
if errorlevel 1 (
  echo Necesitas instalar Node.js LTS desde https://nodejs.org/
  pause
  exit /b 1
)
echo Instalando dependencias...
npm install
if errorlevel 1 (
  echo Hubo un error en npm install.
  pause
  exit /b 1
)
echo.
echo Listo. Arrancando CHALLENGE DYNASTY...
npm run dev
pause
