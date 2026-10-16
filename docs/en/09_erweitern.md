# 9 Extending the program

## 9.1 Architecture

```
run_Batch.m / run_Einzel.m / Start_App.m      entry points, read config.m
        │
        ▼
+videoauswertung/+kern                        evaluation, no user interface code
  auswerten_Batch ──┐                         all videos of a folder (parfor)
  auswerten_Einzel ─┤                         one video, optional live view
                    ▼
  werte_Messvideo                             one video with metadata (both paths)
    lies_Messlauf                             run, recording, settings from the path
    finde_Kalibrierung                        calibration video in the group folder
    lies_Laborbuchzeile                       required lab notebook values
    werte_Video_aus                           per sensitivity: calibration, frames, physics
      kalibriere_Massstab                     ruler → mm/px
      erkenne_Blasen, verfolge_Blasen         per frame
      einlauflaenge, berechne_Physik          at the end
  wiederhole_Lauf                             repeat a run from lauf_config_*.json
        │
        ▼
+videoauswertung/+io                          read lab notebook, write CSV
+videoauswertung/+plots                       one function per plot, PlotStil
+videoauswertung/+gui                         user interface, calls only +kern and +plots
```

Rules:

- The core calls no user interface functions (`uifigure`, `uiaxes`,
  `drawnow`, `waitbar`). Feedback (live image, progress, abort) is passed
  in as functions in the argument `rueckmeldung`.
- Every numerical value that affects the result is in `config.m`.
- Paths only from `cfg.pfade`, never relative to the current folder.
- Errors in the core are `error(...)` with an identifier
  `videoauswertung:...`; the user interface displays them.

## 9.2 Adding a new plot

1. New file `+videoauswertung/+plots/plot_<Name>.m` following the pattern
   of `plot_Profil.m`:

   ```matlab
   function fig = plot_Name(daten, stil, ax)
       if nargin < 3, ax = []; end
       [fig, ax] = videoauswertung.plots.zielachse(stil, ax);
       % ... draw ...
       xlabel(ax, stil.text('position'));
       stil.formatiere(ax);
   end
   ```

2. Add new labels with `de` and `en` to `PlotStil.texte()`.
3. Optionally offer the plot in the user interface tab "Ergebnisse"
   (`VideoAnalysisApp.m`, functions `zeigeErgebnisse`, `zeichneErgebnis`).
4. Add a test to `tests/test_Plots.m`.

## 9.3 Adding a new result quantity

1. Compute it per data point in `berechne_Physik` and add it as a column
   to `rohdaten`.
2. Add it to `DataVars` in the `grpstats` line; `mean_` and `std_` then
   appear in the result table (the count is shared by all quantities in
   `GroupCount`).
3. Add it to the column reference in chapter 4.
4. Run the regression test: existing columns must remain unchanged; new
   columns do not disturb the comparison.

## 9.4 Tests

```matlab
run('tests/run_AllTests.m')
```

| Test | Checks | Duration |
|---|---|---|
| `test_Config` | `config.m` valid, checks work, paths independent of the working folder | < 1 s |
| `test_Kern` | folder names, entrance length, calibration assignment, lab notebook check, export per setup, run file round trip | approx. 2 s |
| `test_Plots` | every plot in de/en, saving as PNG/PDF | approx. 20 s |
| `test_GuiStart` | user interface starts and closes, initial values from `config.m` | approx. 5 s |
| `test_GuiLauf` | interface run = script run = repetition from the run file (byte-identical) | approx. 4 min |
| `test_Regression` | results equal the reference in `tests/referenz/` | approx. 10 min |

`test_GuiLauf` and `test_Regression` need the measurement videos; without
them they are skipped.

If an intended extension changes the results, `test_Regression` fails.
Then inspect the deviations (`tools/vergleiche_Ergebnisse.m` compares two
result folders) and, if they are correct, replace the files in
`tests/referenz/` with the new results.
