#!/bin/bash
# APK firmado para distribución. Las credenciales llegan SOLO por variables
# de entorno; nunca se escriben en export_presets.cfg ni en el repositorio.
#
#   export GODOT_ANDROID_KEYSTORE_RELEASE_PATH="C:/ruta/driverd-release.keystore"
#   export GODOT_ANDROID_KEYSTORE_RELEASE_USER="driverd"
#   read -rs GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD; export GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD
#   bash tools/build_release_apk.sh
set -eu
cd "$(dirname "$0")/.."
for v in GODOT_ANDROID_KEYSTORE_RELEASE_PATH GODOT_ANDROID_KEYSTORE_RELEASE_USER GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD; do
  if [ -z "${!v:-}" ]; then echo "Falta la variable $v"; exit 1; fi
done
[ -f "$GODOT_ANDROID_KEYSTORE_RELEASE_PATH" ] || { echo "No existe el keystore: $GODOT_ANDROID_KEYSTORE_RELEASE_PATH"; exit 1; }

export JAVA_HOME="C:/Users/User/driverd-tools/jdk-17.0.20.1+1"
export ANDROID_HOME="C:/Users/User/driverd-tools/android-sdk"
export PATH="$JAVA_HOME/bin:$PATH"
OUT=build/driverd-vr.apk
mkdir -p build
rm -f "$OUT"
"/c/Users/User/driverd-tools/godot/Godot_v4.7.2-stable_win64_console.exe" --headless --path . --export-release "Meta Quest" "$OUT"
[ -f "$OUT" ] || { echo "EXPORT FALLÓ"; exit 1; }

BT="$ANDROID_HOME/build-tools/36.1.0"
"$BT/aapt.exe" dump badging "$OUT" | grep -E "^package|native-code"
"$BT/aapt.exe" dump xmltree "$OUT" AndroidManifest.xml | grep -q "com.oculus.intent.category.VR" && echo "categoría VR de Quest: ok"
"$BT/apksigner.bat" verify --print-certs "$OUT" | head -2
sha256sum "$OUT"
echo "APK FIRMADO LISTO: $OUT"
