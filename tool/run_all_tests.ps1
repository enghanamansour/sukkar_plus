# Runs every automated test suite (requires Flutter 3.47.8 and Node >= 22.6).
$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
Push-Location "$root\packages\sukkar_core"; dart pub get; dart test; Pop-Location
Push-Location "$root\app"; flutter pub get; flutter test; Pop-Location
Push-Location "$root\supabase\tests"; npm install; npm test; Pop-Location
