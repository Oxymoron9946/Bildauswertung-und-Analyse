# 3 Configuration

All settings are in `config.m` in the project folder. The file returns a
struct `cfg`; scripts and the user interface read only this struct.

```matlab
cfg = config();                 % default values
cfg.detektion.sens = 0.90;      % change for this run
videoauswertung.kern.auswerten_Batch(cfg, 'PTFE_1000_600');
```

Make permanent changes directly in `config.m`. Every run stores its
complete settings in `output/lauf_config_<time>.json` (chapter 6.4).

The **Effect** column describes what a change does. Values with a strong
effect are printed in bold; before changing them, compare the results with
earlier ones.

## 3.1 Paths (`cfg.pfade`)

| Entry | Meaning | Default |
|---|---|---|
| `projekt` | project folder (location of `config.m`) | – |
| `messdaten` | folder containing the measurement folders | project folder |
| `laborbuch` | lab notebook CSV | `data/Laborbuch.csv` |
| `ausgabe` | result CSV files, plots, run files | `output/` |

All paths are absolute; the current MATLAB folder does not matter.

## 3.2 Video and calibration (`cfg.video`, `cfg.kalibrierung`)

Entries without a prefix belong to `cfg.kalibrierung`.

| Entry | Meaning | Unit | Default | Effect |
|---|---|---|---|---|
| `video.dateimuster` | file name of the camera AVIs | – | `XSM-3520 Camera 0330_*.avi` | adapt for a different camera |
| `video.fps` | frame rate if the path contains no `<n>fps` | 1/s | 200 | scales all velocities linearly |
| `ordnermuster` | name of the calibration folders | – | `Kalibrierung_*` | – |
| `rasterweite_mm` | distance between two ruler ticks | mm | 0.525 | scales all lengths and velocities linearly |
| `suchbereich_rel` | vertical search strip for the ruler | fraction of image height | [0.30 0.80] | ruler must lie inside |
| `band_oben_px`, `band_unten_px` | band around the ruler line | px | 60, 15 | low |
| `rand_px` | ignored image margin | px | 25 | low |
| `glaettung_px` | smoothing of the intensity profile | px | 5 | too large: ticks merge |
| `prominenz_rel` | minimum height of a tick | fraction of maximum | 0.10 | too large: ticks are missed |
| `min_strichabstand_px` | minimum distance between two ticks | px | 8 | must be smaller than the tick distance in the image (≈ 9.6 px) |
| `min_striche` | minimum number of ticks | – | 10 | below that, the calibration fails |
| `raster_toleranz_rel` | permitted deviation from the median tick distance | – | 0.25 | low |

## 3.3 Lab notebook corrections (`cfg.laborbuch`)

| Entry | Meaning | Unit | Default |
|---|---|---|---|
| `co2_anteil_druck` | CO₂ fraction for pressure calibrations, independent of the lab notebook; `NaN` = use the lab notebook value | – | 0 |

## 3.4 Detection (`cfg.detektion`)

| Entry | Meaning | Unit | Default | Effect |
|---|---|---|---|---|
| `sens` | sensitivity of the adaptive threshold; vector = sweep | – (0…1) | 0.95 | **high**: 0.85 instead of 0.95 changes the means per video by up to 6 %, single bins by up to 100 % |
| `clahe_kacheln`, `clahe_clip` | contrast equalisation (adapthisteq) | – | [4 8], 0.01 | depends on illumination |
| `median_px` | median filter | px | [3 3] | low |
| `close_hoehe_px`, `close_breite_px` | closing cracks inside the bubbles | px | 5, 5 | too large: bubbles and slugs merge |
| `staub_px` | smallest black noise area in the slug | px² | 15 | low |
| `min_slug_px` | smallest white slug area after filling | px² | 50 | low |
| `min_flaeche_px` | smallest object area for the channel height | px² | 100 | low |
| `band_halb_px` | half width of the band around the centre line | px | 2 | medium: wider → more spurious edges |
| `strahl_max_px`, `strahl_anteil`, `strahl_min_px` | search range of the edge classification | px, –, px | 20, 0.8, 2 | medium |
| `abstand_ersatz_px` | substitute edge distance if no median can be determined | px | 50 | rarely effective |
| `min_blase_px` | discard bubbles up to this length | px | 5 | low |
| `randabstand_px` | discard unit cells at the image edge | px | 2 | low |
| `fragmente_verbinden` | join bubbles split by reflections | – | `false` | **high**, experimental: in some videos it also joins real bubbles; off by default (chapter 8) |
| `fragment_schwelle_rel` | apparent slug if shorter than this fraction of the typical slug length | – | 0.7 | only with `fragmente_verbinden` |
| `fragment_min_slugs`, `fragment_klassen` | minimum number of slugs, histogram classes for the typical slug length | – | 4, 10 | only with `fragmente_verbinden` |

## 3.5 Channel model (`cfg.kanal`)

| Entry | Meaning | Unit | Default |
|---|---|---|---|
| `init_frames` | frames used to estimate the channel walls | – | 10 |
| `stuetzabstand_px` | spacing of the support points | px | 20 |
| `min_gueltig_rel` | minimum fraction of valid support points per frame | – | 0.3 |
| `breite_tol_rel`, `sprung_rel`, `kruemmung_rel`, `streuung_rel` | thresholds for implausible support points (fraction of channel width) | – | 0.08, 0.05, 0.03, 0.04 |
| `min_hoehe_rel` | minimum height in the fallback model (if the estimate fails) | – | 0.85 |

Effect: only for difficult images (reflections at the wall, fluctuating
illumination). Check with the live view (red lines).

## 3.6 Tracking (`cfg.tracking`)

| Entry | Meaning | Unit | Default | Effect |
|---|---|---|---|---|
| `max_sprung_px` | largest displacement per frame | px | 50 | **limits the measurable velocity** to ≈ max_sprung_px · s · f (50 px · 0.055 mm/px · 200 1/s ≈ 0.55 m/s) |
| `rueckwaerts_px` | tolerated backward movement | px | 2 | low |
| `min_frames` | minimum number of frames per bubble | – | 10 | medium: smaller → more but less reliable data points |

## 3.7 Physics and entrance length (`cfg.physik`, `cfg.einlauf`)

| Entry | Meaning | Unit | Default | Effect |
|---|---|---|---|---|
| `physik.bin_mm` | bin width (increased to ceil(2 · L_B)/2 if smaller than L_B) | mm | 4 | determines number and smoothing of the bins |
| `physik.v_max_m_s` | largest plausible velocity | m/s | 5 | practically no effect (tracking limits more strongly) |
| `physik.plateau_rel` | reference range for the stable measurement zone | fraction of bins | [0.20 0.80] | medium |
| `physik.plateau_schwelle` | a bin counts if count ≥ threshold · median | – | 0.50 | medium: higher → shorter measurement zone |
| `einlauf.rho_kg_m3` | density of the continuous phase | kg/m³ | 1000 | shifts the entrance length |
| `einlauf.mu_Pa_s` | viscosity of the continuous phase | Pa·s | 0.001 | shifts the entrance length |
| `einlauf.faktor` | L_ein = factor · Re · d_h | – | 0.05 | shifts the entrance length |

## 3.8 Plots, display, user interface

| Entry | Meaning | Default |
|---|---|---|
| `plots.sprache` | plot labels `'de'` or `'en'` | `'de'` |
| `plots.breite_cm`, `plots.hoehe_cm` | plot size [cm] | 16, 9 |
| `plots.formate` | output formats | `{'png', 'pdf'}` |
| `plots.dpi` | resolution of the PNG files | 300 |
| `plots.batch` | profile plots after every batch | `true` |
| `anzeige.live` | live view during the evaluation | `false` (user interface and `run_Einzel`: on) |
| `anzeige.jedes_n_frame` | show every n-th frame | 10 |
| `anzeige.kalibrierung` | show the calibration check | `false` |
| `gui.sens_schritt` | step of the sensitivity sweep in the batch of the user interface | 0.05 |
