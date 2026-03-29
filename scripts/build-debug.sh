#!/usr/bin/env bash
# build-debug.sh — Construye e instala el APK debug en el S25
# Uso: ./scripts/build-debug.sh
# Requiere: GOOGLE_SERVER_CLIENT_ID en el entorno o en .env.local
set -euo pipefail

FLUTTER="/Users/juliansalcedo/Applications/Flutter/flutter/bin/flutter"
ADB="$HOME/Library/Android/sdk/platform-tools/adb"
MOBILE_DIR="$(dirname "$0")/../mobile"

# Cargar .env.local si existe (nunca commitear ese archivo)
ENV_FILE="$(dirname "$0")/../.env.local"
if [ -f "$ENV_FILE" ]; then
  # shellcheck disable=SC2046
  export $(grep -v '^#' "$ENV_FILE" | xargs)
fi

if [ -z "${GOOGLE_SERVER_CLIENT_ID:-}" ]; then
  echo "❌  Falta GOOGLE_SERVER_CLIENT_ID"
  echo "   Opción 1: export GOOGLE_SERVER_CLIENT_ID=<tu-web-client-id> && ./scripts/build-debug.sh"
  echo "   Opción 2: crea scripts/../.env.local con GOOGLE_SERVER_CLIENT_ID=<valor>"
  exit 1
fi

echo "✅  GOOGLE_SERVER_CLIENT_ID detectado"
echo "📦  Construyendo APK debug..."

cd "$MOBILE_DIR"
"$FLUTTER" build apk --debug \
  --dart-define=GOOGLE_SERVER_CLIENT_ID="$GOOGLE_SERVER_CLIENT_ID"

APK="build/app/outputs/flutter-apk/app-debug.apk"
echo "📲  Instalando en el dispositivo..."
"$ADB" install -r "$APK"
echo "🎉  Listo: $APK instalado"
