$ErrorActionPreference = 'Stop'

$projectRoot = Split-Path -Parent $PSScriptRoot
Push-Location $projectRoot

try {
    Write-Host '1/6 UserStore-ObjectBox-Modell aktualisieren'
    Push-Location 'packages\user_store'
    try {
        dart pub get
        dart run build_runner build
    }
    finally {
        Pop-Location
    }

    Write-Host '2/6 Flutter-Abhängigkeiten laden'
    flutter pub get

    Write-Host '3/6 Neue und geänderte Dart-Dateien formatieren'
    dart format `
        lib\controllers\puzzle_app_controller.dart `
        lib\data\repositories\in_memory_puzzle_catalog_repository.dart `
        lib\data\repositories\objectbox_puzzle_catalog_repository.dart `
        lib\data\repositories\puzzle_catalog_repository.dart `
        lib\data\repositories\puzzle_user_repository.dart `
        lib\data\stores\user_store_manager.dart `
        lib\domain\fen_position.dart `
        lib\domain\glicko2.dart `
        lib\domain\puzzle_difficulty.dart `
        lib\domain\puzzle_feedback.dart `
        lib\domain\puzzle_mode_plan.dart `
        lib\domain\puzzle_range.dart `
        lib\domain\puzzle_record.dart `
        lib\domain\puzzle_selection.dart `
        lib\ui\mobile\widgets\mobile_puzzle_action_bar.dart `
        lib\ui\mobile\widgets\mobile_puzzle_more_sheet.dart `
        lib\ui\mobile\widgets\mobile_puzzle_side_menu.dart `
        lib\ui\mobile\widgets\mobile_puzzle_stats_panel.dart `
        lib\ui\widgets\puzzle_sidebar.dart `
        packages\user_store\lib\src\puzzle_run_entity.dart `
        packages\user_store\lib\src\puzzle_settings_entity.dart `
        packages\user_store\lib\src\user_store_meta_entity.dart `
        test

    Write-Host '4/6 Flutter-Analyse'
    flutter analyze

    Write-Host '5/6 Modus- und Wertungstests'
    flutter test

    Write-Host '6/6 Bestehende Datenbanktests'
    & '.\tool\test_database_patch.ps1'

    Write-Host ''
    Write-Host 'Performance- und Spielmodi-Patch vorbereitet.'
    Write-Host 'Nächster Test: flutter build windows'
}
finally {
    Pop-Location
}
