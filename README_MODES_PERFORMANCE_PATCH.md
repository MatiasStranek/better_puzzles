# Better Puzzles – Performance, Aufgaben, Streak und Storm

Dieser Overlay-Patch setzt auf dem bereits funktionierenden `.bpuzzles`-Import auf. Er baut **keine neue PuzzleCatalog-Datenbank** und verändert das Katalogschema nicht. Die vorhandene Datei `lichess_puzzles_2026_07.bpuzzles` kann weiterverwendet werden.

## Was der Patch ändert

### Schnellere ObjectBox-Auswahl

Die bisherige Abfrage sortierte große Ratingbereiche mit Millionen möglicher Datensätze. Die neue Auswahl:

- fragt bei aufsteigender Auswahl jeweils nur **ein exaktes Rating** ab,
- verwendet für Random-Auswahl `randomKey` mit einem Pivot,
- führt ObjectBox-Abfragen mit `findFirstAsync()` bzw. `findAsync()` außerhalb des UI-Isolates aus,
- zeigt die gemessene Abfragezeit beim aktuellen Puzzle an.

### Aufgaben

- gewertetes Training oder freies Range-Training,
- Schwierigkeitsstufen `−600`, `−300`, `±0`, `+300`, `+600`,
- lokale Puzzle-Wertung mit Rating, Ratingabweichung und Volatilität,
- gelöst = Glicko-2-Sieg gegen das Puzzle,
- erster Fehler = Glicko-2-Niederlage gegen das Puzzle,
- die Wertung ist lokal und wird nicht mit einem Lichess-Konto synchronisiert.

### Puzzle Streak

- maximal 149 zunehmend schwierigere Puzzles,
- Verteilung nach den öffentlichen Lichess-Ratingbändern,
- ein Fehler beendet den Lauf,
- aktueller Streak und persönlicher Bestwert im UserStore.

### Puzzle Storm

- Start bei 3:00 Minuten,
- Uhr startet mit dem ersten Zug,
- Fehler: `−10 Sekunden`, Combo wird zurückgesetzt,
- Zeitboni: Combo 5 `+3s`, 12 `+5s`, 20 `+7s`, 30 und danach jede weitere Zehner-Combo `+10s`,
- maximal 137 zunehmend schwierigere Puzzles,
- Score, Combo, Fehler, Timer und Bestwerte im UserStore.

## Wichtige Annäherung

Die öffentliche Lichess-CSV enthält nicht die internen Qualitätsklassen, die Lichess für seine serverseitige Streak-/Storm-Auswahl verwendet. Dieser Patch übernimmt die veröffentlichten Ratingverteilungen und verwendet `RatingDeviation`, `Popularity` und `NbPlays` als lokale Qualitätsfilter. Wenn ein enger Filter kein Puzzle findet, wird kontrolliert auf weniger strenge Filter zurückgefallen.

## Offizielle Referenzen

- Streak-Auswahl: <https://github.com/lichess-org/lila/blob/master/modules/puzzle/src/main/PuzzleStreak.scala>
- Storm-Auswahl: <https://github.com/lichess-org/lila/blob/master/modules/storm/src/main/StormSelector.scala>
- Storm-Konfiguration: <https://github.com/lichess-org/lila/blob/master/ui/storm/src/config.ts>
- Puzzle-Schwierigkeit: <https://github.com/lichess-org/lila/blob/master/modules/puzzle/src/main/PuzzleDifficulty.scala>
- Puzzle-Wertungsabschluss: <https://github.com/lichess-org/lila/blob/master/modules/puzzle/src/main/PuzzleFinisher.scala>
- Glicko-2-Verfahren: <https://glicko.net/glicko/glicko2.pdf>

## Installation nach dem Entpacken

PowerShell im Projektordner:

```powershell
Set-ExecutionPolicy -Scope Process Bypass -Force
.\tool\setup_modes_performance_patch.ps1
```

Das Skript:

1. aktualisiert das getrennte UserStore-ObjectBox-Modell,
2. lädt Flutter-Abhängigkeiten,
3. formatiert die neuen Dateien,
4. führt `flutter analyze` aus,
5. führt Modus-/Wertungstests aus,
6. führt die bestehenden Datenbanktests aus.

Anschließend zuerst unter Windows testen:

```powershell
flutter build windows
flutter run -d windows
```

Der bereits importierte Katalog sollte beim Start wieder automatisch geöffnet werden. Ein Neuimport der 6-GB-Datei ist nicht vorgesehen.
