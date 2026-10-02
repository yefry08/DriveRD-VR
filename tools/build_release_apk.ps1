# APK firmado desde PowerShell. Pide la contraseña sin mostrarla y la pasa
# solo como variable de entorno de este proceso; no se guarda en ningún archivo.
#   powershell -ExecutionPolicy Bypass -File tools\build_release_apk.ps1
param(
    [string]$Keystore = "C:\Users\User\driverd-release.keystore",
    [string]$Alias = "driverd"
)
$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
$keytool = "C:\Users\User\driverd-tools\jdk-17.0.20.1+1\bin\keytool.exe"

if (-not (Test-Path $Keystore)) {
    Write-Host "No existe $Keystore. Créalo primero (te pedirá la contraseña):"
    Write-Host "& `"$keytool`" -genkeypair -v -keystore $Keystore -alias $Alias -keyalg RSA -keysize 2048 -validity 10000"
    exit 1
}

$secure = Read-Host -AsSecureString "Contraseña del keystore"
$bstr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secure)
try {
    $env:GODOT_ANDROID_KEYSTORE_RELEASE_PATH = $Keystore.Replace('\', '/')
    $env:GODOT_ANDROID_KEYSTORE_RELEASE_USER = $Alias
    $env:GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($bstr)
    # Bash de Git (no el de WSL, que no ve las rutas /c/...)
    $bash = @("C:\Users\User\AppData\Local\hermes\git\usr\bin\bash.exe",
              "C:\Program Files\Git\bin\bash.exe") | Where-Object { Test-Path $_ } | Select-Object -First 1
    if (-not $bash) { throw "No encontré Git Bash" }
    Push-Location $root
    & $bash tools/build_release_apk.sh
    $rc = $LASTEXITCODE
    Pop-Location
} finally {
    [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr)
    Remove-Item Env:GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD -ErrorAction SilentlyContinue
}
exit $rc
