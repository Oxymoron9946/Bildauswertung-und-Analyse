# 6 User interface

The user interface calls the same functions as the scripts
(`videoauswertung.kern.auswerten_Einzel` or `auswerten_Batch`) and produces
the same results. Its labels are German; the table in 6.3 gives the English
meaning of every element.

Start in MATLAB in the project folder:

```matlab
Start_App
```

## 6.1 Single video

![User interface in single video mode](../bilder/gui_einzel.png)

1. Select **Modus** (mode) "Einzelvideo" (single video).
2. Click **Auswählen…** (select) and choose the measurement video (`.avi`)
   in the recording folder.
3. If required, change **Sens. Start** (sensitivity of the threshold).
4. **Live-Ansicht** (live view) shows every n-th frame with the detected
   channel walls (red), bubble boundaries (green/red) and the bubble
   length in mm. **Kalibrierung zeigen** (show calibration) draws the
   ruler check image into the tab "Kalibrierung".
5. **Start**. During the evaluation, the tab "Live-Ansicht" shows the
   current frame with the detection (chapter 5.3).

![Live view during the evaluation](../bilder/gui_live.png)

After the run, the interface switches to the tab "Ergebnisse" (results).
There, **Darstellung** (view) switches between the three plots of the
single video (chapter 5.2).

## 6.2 Batch

![User interface in batch mode](../bilder/gui_batch.png)

1. Select **Modus** "Batch (Ordner)" (batch, folder).
2. Click **Auswählen…** and choose the measurement folder (e.g.
   `PTFE_1000_600`).
3. **Sens. Start** and **Sens. Ende** (end): with equal values, every video
   is evaluated once; with different values, every video is evaluated for
   each sensitivity in steps of `cfg.gui.sens_schritt` (0.05) (column
   `UsedSensitivity`).
4. **Start**. A bar shows the progress (videos finished / total). Live view
   and calibration check are switched off in the batch.
5. In the tab "Ergebnisse", the velocity and bubble length profile of every
   setting can be selected (chapter 5.1).

**Stop** aborts the run. In the batch, the parallel workers are terminated;
videos already finished are not saved. In single video mode, Stop takes
effect at the next displayed frame (only with the live view).

## 6.3 Controls

| Element (German label) | Meaning | Acts on | Initial value from |
|---|---|---|---|
| Modus: Einzelvideo / Batch (Ordner) | mode: single video / batch (folder) | `auswerten_Einzel` or `auswerten_Batch` | – |
| Pfad / Auswählen… | path / select | measurement video or folder; the dialog opens in `cfg.pfade.messdaten` | – |
| Sens. Start | sensitivity, start | `cfg.detektion.sens` (single) or start of the sweep (batch) | `cfg.detektion.sens(1)` |
| Sens. Ende | sensitivity, end | end of the sweep (batch only) | `cfg.detektion.sens(end)` |
| Jedes N-te Frame zeigen | show every n-th frame | `cfg.anzeige.jedes_n_frame` | `config.m` |
| Live-Ansicht | live view | `cfg.anzeige.live` | on |
| Kalibrierung zeigen | show calibration | `cfg.anzeige.kalibrierung` | off |
| Start / Stop | start / abort the run | – | – |
| Tab Live-Ansicht | live view tab | `plots.zeige_Live`, progress bar in the batch | – |
| Tab Kalibrierung | calibration tab | `plots.zeige_Kalibrierung` | – |
| Tab Ergebnisse | results tab | `plot_Laenge_Position`, `plot_Profil`, `plot_Geschwindigkeit_Laenge` or `plot_Verlauf` | – |

All other settings (paths, detection, plots) are taken unchanged from
`config.m`. The interface can also be started with modified settings:

```matlab
cfg = config();
cfg.plots.sprache = 'en';
videoauswertung.gui.VideoAnalysisApp(cfg);
```

## 6.4 Repeating a run from a script

Every run, from the interface or from a script, writes its complete
settings to `output/lauf_config_<time>.json` (type of run, target, time,
code version and all `cfg` entries).

```matlab
datei = 'output/lauf_config_20261014_201500.json';
videoauswertung.kern.wiederhole_Lauf(datei)                          % repeat the run
videoauswertung.kern.wiederhole_Lauf(datei, 'output/wiederholung')   % into a separate folder
[cfg, lauf] = videoauswertung.io.lade_Laufconfig(datei);             % load the settings only
```

## 6.5 Error messages

Errors from the evaluation appear in a message window with the cause; the
status line shows "Fehler!" (error). In the batch, individual faulty videos
are only skipped; the reasons appear in the MATLAB command window
(`ÜBERSPRUNGEN: …`, chapter 4.4).
