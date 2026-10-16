# 4 Evaluation and results

## 4.1 Procedure

```
measurement folder ──► find all measurement videos (cfg.video.dateimuster, without calibration folders)
                         │
                         ▼  per video (in parallel)
                       run + recording from the path ── lab notebook row (required values)
                       calibration video in the group folder ── scale mm/px
                         │
                         ▼  per frame
                       detect bubbles ── track bubbles across frames
                         │
                         ▼  at the end of the video
                       velocity, lengths, position ── bins ── stable measurement zone
                         │
                         ▼  all videos
                       CSV per setup ── profile plots per setting
```

The single evaluation (`run_Einzel`, user interface "Einzelvideo") runs
through the same chain for one video and writes the same columns.

## 4.2 Output files

All outputs are written to `cfg.pfade.ausgabe` (default `output/`):

| File | Content |
|---|---|
| `Output_MassTransfer/Auswertung_Masse_<Material>_<Shape>_<Channel>um_<Length>cm_<CO2>molCO2_<Needle>um.csv` | batch, mass transfer measurements of one setup |
| `Output_PressureCalibration/Auswertung_Druck_….csv` | batch, pressure calibrations of one setup |
| `…/plots/Gas_<jG>_Liq_<jL>_<Material>_<Shape>_<Channel>um_Geschwindigkeit.png/.pdf` | velocity profile u_B(x) per setting |
| `…/plots/…_Blasenlaenge.png/.pdf` | bubble length profile L_B(x) per setting |
| `Output_…/Analysis_<Mass/Pressure>_<run>_<recording>.csv` | single evaluation of one video |
| `lauf_config_<timestamp>.json` | complete settings of the run (chapter 6.4) |

An existing file with the same name is overwritten.

## 4.3 Column reference

Semicolon-separated, decimal point. One row is one bin along the channel
for one video (and one sensitivity).

**Metadata** (identical for all bins of a video)

| Column | Meaning | Unit | Source |
|---|---|---|---|
| `GasVelocity` | superficial gas velocity j_G | m/s | folder name |
| `LiquidVelocity` | superficial liquid velocity j_L | m/s | folder name |
| `CameraPosition` | camera position | – | folder name |
| `Aufnahme` | recording folder, e.g. `200fps_002` | – | folder name |
| `Material` | channel material | – | folder name |
| `Geometrie` | cross-section: `R` round, `Q` square | – | folder name |
| `Kanal_um` | channel size (diameter or edge length) | µm | folder name |
| `Nadel_um` | inner diameter of the gas needle | µm | folder name |
| `Reaktor_cm` | reactor length | cm | lab notebook `Kanallaenge` |
| `Druck_Pa_Auslass` | ambient pressure at the outlet | Pa | lab notebook |
| `Temperatur_C` | ambient temperature | °C | lab notebook |
| `CO2_Anteil` | CO₂ fraction in the gas | – | lab notebook (pressure calibration: `cfg.laborbuch.co2_anteil_druck`) |
| `Messart` | `Massentransfer` (mass transfer) or `Druckkalibrierung` (pressure calibration) | – | folder name (`_Druck`) |
| `UsedSensitivity` | sensitivity of the threshold used | – | `cfg.detektion.sens` |

**Results per bin**

| Column | Meaning | Unit |
|---|---|---|
| `BinCenter_mm` | bin centre, position in the reactor from the inlet | mm |
| `GroupCount` | number of data points in the bin (bubbles × frame pairs) | – |
| `mean_BubbleLength_mm`, `std_…` | bubble length L_B, mean and standard deviation | mm |
| `mean_UnitCellLength_mm`, `std_…` | unit cell length L_UC | mm |
| `mean_SlugLength_mm`, `std_…` | slug length L_S = L_UC − L_B | mm |
| `mean_VoidFraction`, `std_…` | length fraction of the bubble L_B/L_UC | – |
| `mean_Speed_m_s`, `std_…` | bubble velocity u_B | m/s |

Only bins inside the stable measurement zone appear (chapter 7.5).

## 4.4 Reading the log

The MATLAB command window shows (messages are German):

| Message | Meaning | Action |
|---|---|---|
| `Laborbuch geladen: N Einträge` | lab notebook loaded | – |
| `Starte parallele Batch-Auswertung für N Messvideos` | number of videos found | plausible? |
| `ÜBERSPRUNGEN: Der Videopfad enthält keinen Ordner "Pos_<n>_Kal_<k>"` | skipped: folder structure does not match | chapter 2.1 |
| `ÜBERSPRUNGEN: Kein Kalibriervideo unter …` / `Mehrere Kalibriervideos unter …` | skipped: calibration folder missing or duplicated | chapter 2.1 |
| `ÜBERSPRUNGEN: Ordner "…" wurde im Laborbuch … nicht gefunden` | skipped: lab notebook row missing | chapter 2.2 |
| `ÜBERSPRUNGEN: Im Laborbuch fehlt "…"` | skipped: required value empty | complete the lab notebook |
| `ÜBERSPRUNGEN: Automatische Kalibrierung fehlgeschlagen` | skipped: ruler not detected | check the calibration video (calibration check, chapter 5.3) |
| `Keine stabile Messzone gefunden` | no stable measurement zone: too few data points | short or unsteady video; check the sensitivity |
| `Kanalhöhe konnte nicht zuverlässig bestimmt werden` | channel height not determined in single frames | harmless if rare |
| `ERFOLG: N Zeilen gespeichert in …` | success: result file written | – |
