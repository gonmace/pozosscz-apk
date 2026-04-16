#!/usr/bin/env bash
# Build de release para producción.
# Requiere android/key.properties con datos del keystore real.
# Uso: ./scripts/build_release.sh [URL_OVERRIDE]
# Si no se pasa URL, usa https://api.pozosscz.com por defecto.

set -euo pipefail

API_URL="${1:-https://pozosscz.com}"

if [[ ! -f "android/key.properties" ]]; then
    echo "ERROR: android/key.properties no existe. Crea la keystore de release primero."
    echo "Consulta el plan de despliegue (sección 2) para los pasos."
    exit 1
fi

FLUTTER="/c/Users/gonma/flutter_sdk/bin/flutter"

echo "==> flutter clean"
"$FLUTTER" clean

echo "==> flutter build apk --release --dart-define=API_URL=$API_URL"
"$FLUTTER" build apk --release --dart-define="API_URL=$API_URL"

echo ""
echo "APK generado en: build/app/outputs/flutter-apk/app-release.apk"
echo ""
echo "Para verificar la firma:"
echo "  apksigner verify --print-certs build/app/outputs/flutter-apk/app-release.apk"
