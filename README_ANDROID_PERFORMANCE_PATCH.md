# Better Puzzles – Android-Performance-Patch

Dieser Patch optimiert die Puzzle-Auswahl, ohne das `.bpuzzles`-Format zu
ändern und ohne den 6-GB-Lichess-Katalog neu zu bauen.

## Was geändert wird

- ObjectBox sucht zufällige Puzzles zuerst über eine **exakte, indexierte
  Wertung**.
- Die App sortiert keine große gefilterte Ergebnismenge mehr nach `randomKey`.
- Passende ObjectBox-IDs werden pro Wertung und Filterkombination im RAM
  zwischengespeichert.
- Diese Rating-Caches bleiben bei einem Modus-Reset erhalten.
- Storm behält bei einem Reset die Spielerfarbe bei, damit derselbe warme Cache
  genutzt werden kann. Beim erneuten Wechsel in den Storm-Modus kann die andere
  Farbe gewählt werden.
- Puzzle Streak lädt bis zu 12 kommende Aufgaben vor.
- Puzzle Storm lädt bis zu 24 kommende Aufgaben vor.
- Freie Aufgaben laden bis zu 8, gewertete Aufgaben bis zu 3 Aufgaben vor.
- Muss Storm ausnahmsweise direkt von der Datenbank nachladen, wird die Uhr für
  diese Wartezeit pausiert. Die Geschwindigkeit des Handys verringert dadurch
  nicht den Storm-Score.
- In der bestehenden Zugleiste steht `vorgeladen` und wie viele Aufgaben bereits
  bereitliegen.
- Gleichzeitige aufsteigende Abfragen werden serialisiert, damit Prefetch und
  sichtbarer Ladevorgang nicht denselben Datensatz auswählen.

## Wichtig

- `lichess_puzzles_2026_07.bpuzzles` muss **nicht** neu gebaut werden.
- Die Datenbank muss **nicht** erneut importiert werden.
- Es werden keine ObjectBox-Entities und keine Modelldateien geändert.
- Der bereits auf Android installierte Katalog bleibt kompatibel.
- Die allererste Abfrage nach einem echten Android-Kaltstart kann weiterhin
  etwas langsamer sein, weil Android Datenbank- und Indexseiten vom Speicher
  einlesen muss. Die bisherige katalogweite Sortierarbeit entfällt jedoch.

## Einrichtung und Prüfung

Im Projektordner in PowerShell:

```powershell
Set-ExecutionPolicy -Scope Process Bypass -Force
.\tool\setup_android_performance_patch.ps1
flutter build apk --debug
flutter run -d <android-geraete-id>
```

Danach in dieser Reihenfolge testen:

1. Den bereits importierten Katalog öffnen.
2. Puzzle Storm starten und mehrere Aufgaben lösen.
3. Prüfen, ob in der Zugleiste `vorgeladen` erscheint und die Übergänge sofort
   erfolgen.
4. Storm zurücksetzen und den ersten Ladevorgang erneut prüfen.
5. Puzzle Streak und normale Aufgaben testen.

Falls ein direkter Ladevorgang noch langsam ist, zeigt die Zugleiste weiterhin
seine gemessene Dauer in Millisekunden. Dieser Wert ermöglicht anschließend ein
gerätespezifisches Profiling.
