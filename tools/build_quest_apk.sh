#!/bin/bash
# Build desatendido del APK de Quest con Gradle, tolerante a red lenta.
# Uso: bash tools/build_quest_apk.sh   (log en build/build_quest.log)
set -u
cd "$(dirname "$0")/.."
LOG=build/build_quest.log
mkdir -p build
exec >>"$LOG" 2>&1
echo "=== $(date) inicio ==="
export JAVA_HOME="C:/Users/User/driverd-tools/jdk-17.0.20.1+1"
export ANDROID_HOME="C:/Users/User/driverd-tools/android-sdk"
export PATH="$JAVA_HOME/bin:$PATH"
GV=8.11.1
D="$HOME/.gradle/wrapper/dists/gradle-$GV-bin/bpt9gzteqjrbo1mjrsomdt32c"
mkdir -p "$D"
if [ ! -f "$D/gradle-$GV-bin.zip.ok" ]; then
  EXPECTED=$(curl -sL --retry 10 https://services.gradle.org/distributions/gradle-$GV-bin.zip.sha256 | tr -d "[:space:]")
  [ ${#EXPECTED} -eq 64 ] || EXPECTED=f397b287023acdba1e9f6fc5ea72d22dd63669d59ed4a289a29b1a76eee151c6
  until curl -L -C - --retry 20 --retry-delay 5 -o "$D/gradle-$GV-bin.zip" https://github.com/gradle/gradle-distributions/releases/download/v$GV/gradle-$GV-bin.zip; do echo "reintentando descarga"; sleep 10; done
  GOT=$(sha256sum "$D/gradle-$GV-bin.zip" | cut -d' ' -f1)
  echo "sha256 esperado=$EXPECTED obtenido=$GOT"
  if [ "$EXPECTED" != "$GOT" ]; then echo "CHECKSUM INCORRECTO"; rm -f "$D/gradle-$GV-bin.zip"; exit 1; fi
  rm -f "$D"/*.lck "$D"/*.part
  (cd "$D" && unzip -q -o "gradle-$GV-bin.zip" && touch "gradle-$GV-bin.zip.ok")
  echo "gradle listo"
fi
for intento in 1 2 3 4 5 6; do
  echo "--- export intento $intento $(date)"
  "/c/Users/User/driverd-tools/godot/Godot_v4.7.2-stable_win64_console.exe" --headless --path . --install-android-build-template --export-debug "Meta Quest" build/driverd-vr-debug.apk
  if [ -f build/driverd-vr-debug.apk ]; then break; fi
  sleep 30
done
AAPT="$ANDROID_HOME/build-tools/36.1.0/aapt.exe"
if [ -f build/driverd-vr-debug.apk ]; then
  ls -la build/driverd-vr-debug.apk
  "$AAPT" dump badging build/driverd-vr-debug.apk | head -30
  "$AAPT" dump xmltree build/driverd-vr-debug.apk AndroidManifest.xml | grep -iE "oculus|openxr|category" 
  unzip -l build/driverd-vr-debug.apk | grep "\.so$"
  echo "=== $(date) APK LISTO ==="
else
  echo "=== $(date) EXPORT FALLÓ ==="
fi
