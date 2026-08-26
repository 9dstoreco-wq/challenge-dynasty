#!/bin/zsh
cd "$(dirname "$0")"
echo "CHALLENGE DYNASTY - INSTALACION"
if ! command -v node >/dev/null 2>&1; then
  echo "Necesitas instalar Node.js LTS desde https://nodejs.org/"
  read -r
  exit 1
fi
npm install || exit 1
npm run dev
