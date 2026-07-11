$ErrorActionPreference = "Stop"

$projectRoot = Split-Path -Parent $PSScriptRoot
Push-Location $projectRoot

function Assert-LastExitCode {
  param([Parameter(Mandatory = $true)][string]$Step)

  if ($LASTEXITCODE -ne 0) {
    throw "$Step ist fehlgeschlagen (Exitcode $LASTEXITCODE)."
  }
}

try {
  Write-Host "1/4 Flutter-Abhängigkeiten prüfen"
  flutter pub get
  Assert-LastExitCode "flutter pub get"

  Write-Host "2/4 Performance-Dateien formatieren"
  dart format `
    lib/controllers/puzzle_app_controller.dart `
    lib/data/repositories/in_memory_puzzle_catalog_repository.dart `
    lib/data/repositories/objectbox_puzzle_catalog_repository.dart `
    lib/data/repositories/puzzle_catalog_repository.dart `
    test/puzzle_prefetch_controller_test.dart
  Assert-LastExitCode "dart format"

  Write-Host "3/4 Flutter-Analyse"
  flutter analyze --no-fatal-infos --no-fatal-warnings
  Assert-LastExitCode "flutter analyze"

  Write-Host "4/4 Tests"
  flutter test
  Assert-LastExitCode "flutter test"

  Write-Host ""
  Write-Host "Android-Performance-Patch erfolgreich geprüft."
  Write-Host "Die vorhandene .bpuzzles-Datenbank muss nicht neu importiert werden."
  Write-Host "Nächster Test: flutter run -d <android-device-id>"
}
finally {
  Pop-Location
}
