$ErrorActionPreference = 'Stop'

$projectRoot = Split-Path -Parent $PSScriptRoot
Push-Location $projectRoot

try {
    Write-Host '1/3 Flutter-Abhängigkeiten laden'
    flutter pub get

    Write-Host '2/3 Neue und geänderte Dart-Dateien formatieren'
    dart format `
        lib/app/better_puzzles_app.dart `
        lib/controllers/puzzle_app_controller.dart `
        lib/domain/puzzle_database_status.dart `
        lib/data/import/puzzle_database_import_service.dart `
        lib/ui/shared/puzzle_database_import_dialog.dart `
        lib/ui/widgets/puzzle_sidebar.dart `
        lib/ui/mobile/widgets/mobile_puzzle_side_menu.dart `
        lib/ui/mobile/widgets/mobile_puzzle_more_sheet.dart

    Write-Host '3/3 Flutter-Analyse'
    flutter analyze

    Write-Host ''
    Write-Host 'App-Katalogimport vorbereitet.'
    Write-Host 'Nächster Test: .\tool\test_database_patch.ps1'
}
finally {
    Pop-Location
}
