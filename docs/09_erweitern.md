# 9 Erweitern

## 9.1 Architektur

```
run_Batch.m / run_Einzel.m / Start_App.m      Einstiege, lesen config.m
        │
        ▼
+videoauswertung/+kern                        Auswertung, kein Oberflächencode
  auswerten_Batch ──┐                         alle Videos eines Ordners (parfor)
  auswerten_Einzel ─┤                         ein Video, optional Live-Ansicht
                    ▼
  werte_Messvideo                             ein Video mit Metadaten (beide Wege)
    lies_Messlauf                             Messlauf, Aufnahme, Einstellungen aus dem Pfad
    finde_Kalibrierung                        Kalibriervideo im Gruppenordner
    lies_Laborbuchzeile                       Pflichtangaben
    werte_Video_aus                           je Sensitivität: Kalibrierung, Frames, Physik
      kalibriere_Massstab                     Lineal → mm/px
      erkenne_Blasen, verfolge_Blasen         je Frame
      einlauflaenge, berechne_Physik          am Ende
  wiederhole_Lauf                             Lauf aus lauf_config_*.json erneut ausführen
        │
        ▼
+videoauswertung/+io                          Laborbuch lesen, CSV schreiben
+videoauswertung/+plots                       eine Funktion je Plot, PlotStil
+videoauswertung/+gui                         Oberfläche, ruft nur +kern und +plots
```

Regeln:

- Der Kern ruft keine Oberflächenfunktionen auf (`uifigure`, `uiaxes`,
  `drawnow`, `waitbar`). Rückmeldungen (Live-Bild, Fortschritt, Abbruch)
  kommen als Funktionen im Argument `rueckmeldung` herein.
- Jeder Zahlenwert, der das Ergebnis beeinflusst, steht in `config.m`.
- Pfade nur aus `cfg.pfade`, nie relativ zum aktuellen Ordner.
- Fehler im Kern sind `error(...)` mit einer Kennung `videoauswertung:...`;
  die GUI zeigt sie an.

## 9.2 Einen neuen Plot ergänzen

1. Neue Datei `+videoauswertung/+plots/plot_<Name>.m` nach dem Muster von
   `plot_Profil.m`:

   ```matlab
   function fig = plot_Name(daten, stil, ax)
       if nargin < 3, ax = []; end
       [fig, ax] = videoauswertung.plots.zielachse(stil, ax);
       % ... zeichnen ...
       xlabel(ax, stil.text('position'));
       stil.formatiere(ax);
   end
   ```

2. Neue Beschriftungen in `PlotStil.texte()` mit `de` und `en` eintragen.
3. Optional im GUI-Tab „Ergebnisse“ anbieten
   (`VideoAnalysisApp.m`, Funktionen `zeigeErgebnisse`, `zeichneErgebnis`).
4. Test in `tests/test_Plots.m` ergänzen.

## 9.3 Eine neue Ergebnisgröße ergänzen

1. In `berechne_Physik` je Messpunkt berechnen und als Spalte in
   `rohdaten` aufnehmen.
2. In der `grpstats`-Zeile unter `DataVars` ergänzen; dann erscheinen
   `mean_` und `std_` in der Ergebnistabelle (die Anzahl steht für alle
   Größen gemeinsam in `GroupCount`).
3. Spaltenlexikon in Kapitel 4 ergänzen.
4. Regressionstest laufen lassen: bestehende Spalten müssen unverändert
   bleiben; neue Spalten stören den Vergleich nicht.

## 9.4 Tests

```matlab
run('tests/run_AllTests.m')
```

| Test | Prüft | Dauer |
|---|---|---|
| `test_Config` | `config.m` gültig, Prüfungen greifen, Pfade unabhängig vom Arbeitsordner | < 1 s |
| `test_Kern` | Ordnernamen, Einlauflänge, Kalibrierzuordnung, Laborbuch-Prüfung, Export je Setup, Laufdatei hin und zurück | ca. 2 s |
| `test_Plots` | jeder Plot in de/en, Speichern in PNG/PDF | ca. 20 s |
| `test_GuiStart` | Oberfläche startet und schließt, Startwerte aus `config.m` | ca. 5 s |
| `test_GuiLauf` | GUI-Lauf = Skript-Lauf = Wiederholung aus der Laufdatei (bytegenau) | ca. 4 min |
| `test_Regression` | Ergebnisse gleich der Referenz in `tests/referenz/` | ca. 10 min |

`test_GuiLauf` und `test_Regression` brauchen die Messvideos; ohne sie
werden sie übersprungen.

Ändert eine gewollte Erweiterung die Ergebnisse, schlägt
`test_Regression` fehl. Dann die Abweichungen ansehen
(`tools/vergleiche_Ergebnisse.m` vergleicht zwei Ergebnisordner) und, wenn
sie stimmen, die Dateien in `tests/referenz/` durch die neuen Ergebnisse
ersetzen.
