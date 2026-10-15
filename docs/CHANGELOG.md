# Änderungsprotokoll

Alle Zahlenwerte sind bit-gleich zur Baseline des Stands `0cf713b`
(Tag `archiv/vor-uebergabe`), soweit unten kein freigegebener Fix mit
Beleg steht. Geprüft wird das durch `tests/test_Regression.m`.

## [Unveröffentlicht] – Übergabe-Aufbereitung

### Struktur (keine Wirkung auf Zahlen)

- Gesamter Code im Paket `+videoauswertung` (`+kern`, `+io`, `+plots`, `+gui`).
  Einstellungen nur noch in `config.m`; kein `addpath` mehr außer dem
  Projektordner in den drei Einstiegen `run_Einzel.m`, `run_Batch.m`,
  `Start_App.m`.
- Alle Schwellwerte der Detektion, Kalibrierung, Kanalschätzung, Physik und
  Einlauflänge als benannte Parameter in `config.m`.
- `detect_Bubbles` (923 Zeilen) in benannte Schritte zerlegt
  (`erkenne_Blasen`: binarisieren, Kanalränder, Kanten klassifizieren,
  Alternanz, Region Growing, Blasen, Unit-Cells).
- Mehrfach vorhandene Logik zusammengeführt: Messlauf-Name, Metadaten aus
  dem Ordnernamen und Messart (`lies_Messlauf`), Einlauflänge
  (`einlauflaenge`, vorher doppelt, Batch-Ergebnis wurde verworfen),
  Konfigurationsprüfung (`pruefe_Config`, jetzt auch beim GUI-Start).
- Der Kern enthält keinen Oberflächencode mehr; Live-Ansicht, Abbruch,
  Fortschritt und Kalibrieranzeige laufen über Rückmeldefunktionen.
- Archiviert (nicht mehr im Repository, Stand unter Tag
  `archiv/vor-uebergabe`): `evaluate_DetectionQuality`, `updateProgress`,
  `generate_Calibration_Image`, `GUI_Callback_Template.txt`, auskommentierte
  ROI-Erkennung, `data/Statistik_Ergebnisse_Kanallaenge.csv`, ungenutzte
  Parameter `showBinarySteps`, `showVelocityTracking`.
- Kodierung: alle Dateien UTF-8 (vorher `Start_App.m` und
  `runBatchPipeline.m` UTF-16).

### Verhalten (keine Wirkung auf Zahlen)

- Methodik-Abbildungen (Abb1–9) werden nur noch erzeugt, wenn
  `cfg.abbildungen.exportieren = true`, und zwar nach `cfg.pfade.abbildungen`
  statt in einen festen Linux-Pfad. Abb4 (gesäubertes Binärbild, kaum von
  Abb3 zu unterscheiden) entfällt; Abb3 heißt jetzt `Abb3_Binaer.png`.
- Abb9: Die Bemaßung zeigt die gemessene Blasenlänge; vorher wurden die
  2 px Linienversatz mitgerechnet. Abb6/Abb7: Kantenpunkte größer.
- GUI: Beschriftungen auf Deutsch; die Kalibrierkontrolle erscheint im Tab
  „Kalibrierung“ statt in einem Fenster, das sich nach 5 s schließt.
  Startwerte aus `config.m` (`cfg.gui`, `cfg.anzeige`).
- Batch per Skript: Fortschritt in der Konsole statt Waitbar-Fenster.
- Plots neu (P13–P17): eine Funktion je Plot in `+plots`
  (`plot_Geschwindigkeit_Laenge`, `plot_Laenge_Position`, `plot_Profil`,
  `plot_Verlauf`), gemeinsamer `PlotStil` (Größe in cm, Sprache de/en,
  Formate PNG/PDF, dpi, immer helles Theme). Die Batch-Verlaufsplots
  (vorher `generate_Batch_Plots`, nie aufgerufen) entstehen nach jedem
  Batch im Unterordner `plots` (`cfg.plots.batch`). Mehrere Aufnahmen
  desselben Messpunkts werden als getrennte Linien gezeichnet.
- GUI-Tab „Ergebnisse“ (vorher Platzhalter): zeigt die Plots des letzten
  Laufs, nach einem Batch die Verlaufsplots je Einstellung.
- Einzel- und Batch-Auswertung nutzen dieselbe Funktion je Video
  (`werte_Messvideo`) und schreiben dasselbe Format: Semikolon, alle
  Metadatenspalten (vorher GUI-Einzel mit Komma und ohne Metadaten).
- `run_Einzel.m` ersetzt `scripts/run_Single.m` und verhält sich wie die
  GUI-Einzelauswertung: Kalibriervideo und Offset aus Ordnerstruktur und
  Laborbuch, Bildrate aus dem Pfad. Vorher galten feste Pfade, Offset 0 mm
  und 200 fps.
- Spalten `numel_*` entfallen; sie waren immer gleich `GroupCount`.
- Jeder Lauf schreibt `lauf_config_<Zeit>.json`;
  `videoauswertung.kern.wiederhole_Lauf` wiederholt ihn per Skript.
- Ohne Parallel Computing Toolbox läuft der Batch nacheinander statt mit
  einem Fehler abzubrechen.

### Freigegebene Korrekturen (ändern Zahlen oder Spalten)

Jeder Fix wurde einzeln gegen die Baseline gerechnet und am 14.10.2026
freigegeben. Belege mit vollständigen Tabellen: `docs/belege/`.

| Fix | Änderung | Wirkung auf die vorhandenen Daten |
|---|---|---|
| F01 | Kalibriervideo aus dem eigenen Gruppenordner `Pos_<n>_Kal_<k>`; vorher galt im Batch das zuletzt gefundene Video gleichen Gruppennamens aus beliebigen Teilordnern | PVC_1000_600, Massentransfer, Kameraposition 3: 13 von 39 Videos, je Video bis 0,5 % (nutzten die Kalibrierung der Druckmessung) |
| F02 | Position = Mitte der gemessenen Blase; vorher Nase der stromauf liegenden Nachbarblase | Positionen stromab verschoben, Median 1,3–4,3 mm je Messordner; dadurch andere Bins und Messzonen, Mittelwerte je Video meist < 1 %, Einzelfälle mehr |
| F03 | Sensitivität für GUI und Batch aus `cfg.detektion.sens` (0,95); vorher GUI-Einzel 0,85. Batch wertet einen Sensitivitäts-Vektor aus | Einzelauswertung je Video bis 6 %; Einzel und Batch liefern jetzt dieselben Werte |
| F04 | Bildrate aus dem Aufnahmeordner auch im Batch | keine (alle Videos 200 fps) |
| F06 | CO₂-Anteil 0 für Druckkalibrierungen (`cfg.laborbuch.co2_anteil_druck`); ersetzt den lokalen Patch | nur Spalte `CO2_Anteil` und Dateiname der Druck-Ergebnisse |
| F08 | eine Batch-Datei je Setup statt je Messart | keine (ein Setup je Messart) |
| F10 | neue Spalte `Aufnahme`; Dateiname der Einzelauswertung mit Aufnahme | keine Zahlen; Mehrfachaufnahmen jetzt unterscheidbar |
| F11 | Einzelauswertung prüft Laborbuch-Pflichtangaben wie der Batch; Ersatz-Offset entfällt | keine (alle ausgewerteten Videos haben Einträge) |

Zurückgestellt: **F07** (Fragmente durch Reflexionen verbinden, lokaler
Patch vom 14.10.2026). Als Option `cfg.detektion.fragmente_verbinden`
übernommen, Standard aus. Mit `true` ändern sich 89 von 122 Videos; die
Streuung der Blasenlänge steigt im Median, in einem Fall werden
vermutlich echte Blasen verbunden (Beleg F07).

Nur dokumentiert: F05 (Bin-Breite wird vergrößert), F09 (doppelter
Laborbuch-Schlüssel in Altdaten), siehe Kapitel 8.
