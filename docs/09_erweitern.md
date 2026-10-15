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
  werte_Video_aus                             ein Video: Kalibrierung, Frames, Physik
    kalibriere_Massstab                       Lineal → mm/px
    erkenne_Blasen                            je Frame
    verfolge_Blasen                           je Frame
    berechne_Physik                           am Ende
  lies_Messlauf, finde_Kalibrierung,          Ordnernamen, Laborbuch
  lies_Laborbuchzeile, einlauflaenge
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
   `mean_`, `std_` und `numel_` in der Ergebnistabelle.
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
Ändert eine gewollte Korrektur Zahlen, wird die Referenz erneuert und die
Änderung mit Vorher/Nachher-Beleg im CHANGELOG festgehalten
(`tools/vergleiche_Ergebnisse.m`).
