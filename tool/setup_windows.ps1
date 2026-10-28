# Sukkar Plus — Windows setup helper (run from the repository root in PowerShell).
# Checks tools, runs core tests, generates Flutter platform folders, analyses and
# tests the app. Usage:  powershell -ExecutionPolicy Bypass -File tool\setup_windows.ps1
$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot

function Require($cmd, $hint) {
  if (-not (Get-Command $cmd -ErrorAction SilentlyContinue)) { throw "$cmd not found. $hint" }
}
Require flutter "Install Flutter 3.47.8 stable: https://docs.flutter.dev/get-started/install/windows"
Require git "Install Git for Windows."

$v = (flutter --version --machine | ConvertFrom-Json)
Write-Host "Flutter $($v.frameworkVersion) / Dart $($v.dartSdkVersion)"
if ([version]($v.frameworkVersion -replace '[^0-9.]','') -lt [version]"3.47.0") { throw "Flutter >= 3.47 is required (pdfrx 2.10 needs it)." }

Write-Host "`n== Core package tests"
Push-Location "$root\packages\sukkar_core"
dart pub get
dart analyze
dart test
Pop-Location

Write-Host "`n== Flutter app"
Push-Location "$root\app"
if (-not (Test-Path "android") -or -not (Test-Path "windows")) {
  flutter create . --platforms=android,windows --project-name sukkar_plus --org sa.sukkarplus
}
flutter pub get
flutter analyze
flutter test
Pop-Location

Write-Host "`nDone. Run the demo with:  cd app; flutter run -d windows"
