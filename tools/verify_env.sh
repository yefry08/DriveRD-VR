#!/bin/sh
# Verifica que el entorno de build de DriveRD VR esté completo.
# Uso: sh tools/verify_env.sh
set -u
fail=0
check() { if eval "$2" >/dev/null 2>&1; then echo "  [ok]  $1"; else echo "  [FALTA] $1"; fail=1; fi; }
echo "DriveRD VR - verificación de entorno"
check "godot en PATH"            "godot --version"
check "Godot 4.7.x"              "godot --version | grep -q '^4\.7'"
check "java 17"                  "java -version 2>&1 | grep -q '\"17\.'"
check "ANDROID_HOME definido"    "test -n \"\${ANDROID_HOME:-}\""
check "platform-tools (adb)"     "test -d \"\$ANDROID_HOME/platform-tools\""
check "platforms;android-34"     "test -d \"\$ANDROID_HOME/platforms/android-34\""
check "platforms;android-36"     "test -d \"\$ANDROID_HOME/platforms/android-36\""
check "build-tools;34.0.0"       "test -d \"\$ANDROID_HOME/build-tools/34.0.0\""
check "build-tools;36.1.0"       "test -d \"\$ANDROID_HOME/build-tools/36.1.0\""
check "ndk;29.0.14206865"        "test -d \"\$ANDROID_HOME/ndk/29.0.14206865\""
check "plugin OpenXR Vendors"    "test -f addons/godotopenxrvendors/plugin.gdextension"
exit $fail
