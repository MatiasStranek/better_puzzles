# Better Puzzles – App-Katalogimport

Dieser Patch verbindet die bereits vorbereitete `.bpuzzles`-Infrastruktur mit
der bestehenden Flutter-App, ohne das Hauptlayout umzubauen.

## Neu in der App

- Der vorhandene Menüpunkt **Datenbank** öffnet einen nativen Datei-Picker.
- Auswählbar sind `.bpuzzles`-Pakete.
- Vor dem Import zeigt die App Manifestdaten, Puzzle-Anzahl, Ratingbereich,
  Paketgröße und den temporären Speicherbedarf.
- Nicht kompatible Pakete werden vor dem Kopieren abgelehnt.
- Kopieren und Extrahieren zeigen Fortschritt.
- Nach erfolgreicher Prüfung wird der Katalog atomar aktiviert.
- Das Puzzle-Repository wechselt danach auf ObjectBox.
- Beim nächsten App-Start wird der aktive Katalog automatisch geöffnet.
- Der getrennte UserStore wird unabhängig davon geöffnet und bleibt erhalten.

## Speicherbedarf

Das vollständige Paket ist ungefähr 6 GB groß. Während des Imports liegen im
App-Speicher zeitweise die kopierte `.bpuzzles`-Datei und die extrahierte
`data.mdb` gleichzeitig. Dafür werden ungefähr 12 GB freier App-Speicher
benötigt. Auf Android kann der native Dateiauswahldialog zusätzlich eine
temporäre Kopie anlegen. Daher sollte dort deutlich mehr freier Speicher
vorhanden sein.

## Bewusst nicht enthalten

- Keine Änderung des Schachbrett-Layouts.
- Keine Änderung der Puzzle-Lösungslogik.
- Keine automatische Löschung alter installierter Kataloge.
- Noch keine Verwaltung mehrerer installierter Kataloge im UI.
- Keine Einbettung der 6-GB-Datenbank in APK oder Projekt.

## Einrichtung nach dem Entpacken

```powershell
Set-ExecutionPolicy -Scope Process Bypass -Force
.\tool\setup_app_catalog_import_patch.ps1
```

Danach prüfen:

```powershell
.\tool\test_database_patch.ps1
flutter build apk --debug
```

## Import in der App

1. App starten.
2. Im Seitenmenü **Datenbank** wählen.
3. `lichess_puzzles_2026_07.bpuzzles` auswählen.
4. Manifestdaten kontrollieren.
5. **Importieren** drücken und die App geöffnet lassen.
6. Nach Abschluss wird der ObjectBox-Katalog sofort aktiv.

Der Quelldatei-Pfad außerhalb der App bleibt unverändert. Der aktive Katalog
wird im Application-Support-Verzeichnis der jeweiligen Plattform installiert.
