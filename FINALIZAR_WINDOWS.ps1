$ErrorActionPreference = 'Stop'
Set-Location $PSScriptRoot

Write-Host "==============================================="
Write-Host " CHALLENGE DYNASTY - FINALIZACION WINDOWS"
Write-Host "==============================================="

if (-not (Get-Command node -ErrorAction SilentlyContinue)) {
  throw "Node.js no esta instalado. Instala Node.js 20+ y vuelve a ejecutar este archivo."
}
if (-not (Get-Command npm -ErrorAction SilentlyContinue)) {
  throw "npm no esta disponible en PATH."
}

$envFile = Join-Path $PSScriptRoot '.env.local'
if (-not (Test-Path $envFile)) { throw ".env.local no existe." }

foreach ($line in Get-Content $envFile) {
  if ($line -match '^\s*([^#=]+)=(.*)$') {
    $name = $Matches[1].Trim()
    $value = $Matches[2].Trim()
    [Environment]::SetEnvironmentVariable($name, $value, 'Process')
  }
}

if (-not $env:NEXT_PUBLIC_SUPABASE_URL -or -not $env:NEXT_PUBLIC_SUPABASE_ANON_KEY) {
  throw "Faltan variables publicas de Supabase en .env.local."
}

Write-Host "[1/4] Instalando/reparando dependencias con npm ci..."
npm ci --no-audit --no-fund
if ($LASTEXITCODE -ne 0) { throw "npm ci fallo. Revisa la conexion a Internet y vuelve a ejecutar el script." }

Write-Host "[2/4] Ejecutando verificadores estructurales..."
npm run verify-all
if ($LASTEXITCODE -ne 0) { throw "Uno o mas verificadores estructurales fallaron." }

Write-Host "[3/4] Ejecutando TypeScript..."
npm run typecheck
if ($LASTEXITCODE -ne 0) { throw "TypeScript fallo. El proyecto NO se considera finalizado." }

Write-Host "[4/4] Ejecutando build de produccion..."
npm run build
if ($LASTEXITCODE -ne 0) { throw "Next.js build fallo. El proyecto NO se considera finalizado." }

Write-Host ""
Write-Host "==============================================="
Write-Host " FINALIZADO: VERIFY + TYPECHECK + BUILD = PASS"
Write-Host "==============================================="
Write-Host "Puedes arrancar con: npm run start"
pause
