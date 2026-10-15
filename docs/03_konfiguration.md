# 3 Konfiguration

Alle Einstellungen stehen in `config.m` im Projektordner. Die Datei gibt
einen Struct `cfg` zurück; Skripte und GUI lesen nur diesen.

```matlab
cfg = config();                 % Standardwerte
cfg.detektion.sens = 0.90;      % für diesen Lauf ändern
videoauswertung.kern.auswerten_Batch(cfg, 'PTFE_1000_600');
```

Dauerhafte Änderungen direkt in `config.m` vornehmen. Jeder Lauf speichert
seine vollständigen Einstellungen in `output/lauf_config_<Zeit>.json`
(Kapitel 6.4).

**Herkunft der Werte:** Alle Zahlenwerte stammen aus dem Ausgangsstand
`0cf713b`, wo sie fest im Code standen, und wurden unverändert übernommen.
Ausnahmen: `laborbuch.co2_anteil_druck` (Fix F06), die
`fragment_*`-Einträge (lokaler Patch, Fix F07, Standard aus) und die
Plot- und Anzeigeeinstellungen (neu).

**Wirkung** beschreibt, was eine Änderung bewirkt. Quantitativ untersucht
ist nur die Sensitivität (Abschnitt 3.4); bei allen anderen Werten gilt:
vor einer Änderung mit dem Regressionssatz vergleichen
(`tools/vergleiche_Ergebnisse.m`).

## 3.1 Pfade (`cfg.pfade`)

| Eintrag | Bedeutung | Standard |
|---|---|---|
| `projekt` | Projektordner (aus der Lage von `config.m`) | – |
| `messdaten` | Ordner, unter dem die Messordner liegen | Projektordner |
| `laborbuch` | Laborbuch-CSV | `data/Laborbuch.csv` |
| `ausgabe` | Ergebnis-CSV, Plots, Laufdateien | `output/` |
| `abbildungen` | Methodik-Abbildungen Abb1–9 | `output/abbildungen/` |

Alle Pfade sind absolut; der aktuelle MATLAB-Ordner spielt keine Rolle.

## 3.2 Video und Kalibrierung (`cfg.video`, `cfg.kalibrierung`)

Einträge ohne Präfix gehören zu `cfg.kalibrierung`.

| Eintrag | Bedeutung | Einheit | Standard | Wirkung |
|---|---|---|---|---|
| `video.dateimuster` | Dateiname der Kamera-AVIs | – | `XSM-3520 Camera 0330_*.avi` | andere Kamera → anpassen |
| `video.fps` | Bildrate, falls der Pfad kein `<n>fps` enthält | 1/s | 200 | skaliert alle Geschwindigkeiten linear |
| `ordnermuster` | Name der Kalibrierordner | – | `Kalibrierung_*` | – |
| `rasterweite_mm` | Abstand zweier Linealstriche | mm | 0,525 | skaliert alle Längen und Geschwindigkeiten linear |
| `suchbereich_rel` | vertikaler Suchstreifen für das Lineal | Anteil Bildhöhe | [0,30 0,80] | Lineal muss darin liegen |
| `band_oben_px`, `band_unten_px` | Band um die Linealzeile | px | 60, 15 | gering |
| `rand_px` | ignorierter Bildrand | px | 25 | gering |
| `glaettung_px` | Glättung des Helligkeitsprofils | px | 5 | zu groß: Striche verschmelzen |
| `prominenz_rel` | Mindesthöhe eines Strichs | Anteil Maximum | 0,10 | zu groß: Striche fehlen |
| `min_strichabstand_px` | Mindestabstand zweier Striche | px | 8 | muss kleiner als der Strichabstand im Bild (≈ 9,6 px) sein |
| `min_striche` | Mindestanzahl Striche | – | 10 | darunter gilt die Kalibrierung als fehlgeschlagen |
| `raster_toleranz_rel` | zulässige Abweichung vom Median-Strichabstand | – | 0,25 | gering |

## 3.3 Laborbuch-Korrekturen (`cfg.laborbuch`)

| Eintrag | Bedeutung | Einheit | Standard |
|---|---|---|---|
| `co2_anteil_druck` | CO₂-Anteil für Druckkalibrierungen, unabhängig vom Laborbuch; `NaN` = Laborbuchwert verwenden | – | 0 |

## 3.4 Detektion (`cfg.detektion`)

| Eintrag | Bedeutung | Einheit | Standard | Wirkung |
|---|---|---|---|---|
| `sens` | Sensitivität der adaptiven Schwelle; Vektor = Sweep | – (0…1) | 0,95 | **hoch**: 0,85 statt 0,95 ändert die Mittelwerte je Video um bis zu 6 %, einzelne Bins um bis zu 100 % (Fix F03) |
| `clahe_kacheln`, `clahe_clip` | Kontrastausgleich (adapthisteq) | – | [4 8], 0,01 | Beleuchtungsabhängig |
| `median_px` | Medianfilter | px | [3 3] | gering |
| `close_hoehe_px`, `close_breite_px` | Schließen von Rissen in den Blasen | px | 5, 5 | zu groß: Blasen und Slugs verschmelzen |
| `staub_px` | kleinste schwarze Störfläche im Slug | px² | 15 | gering |
| `min_slug_px` | kleinste weiße Slug-Fläche nach dem Füllen | px² | 50 | gering |
| `min_flaeche_px` | kleinste Objektfläche für die Kanalhöhe | px² | 100 | gering |
| `band_halb_px` | halbe Breite des Bands um die Mittellinie | px | 2 | mittel: breiter → mehr Störkanten |
| `strahl_max_px`, `strahl_anteil`, `strahl_min_px` | Suchweite der Kantenklassifizierung | px, –, px | 20, 0,8, 2 | mittel |
| `abstand_ersatz_px` | Ersatz-Kantenabstand, wenn kein Median bestimmbar | px | 50 | selten wirksam |
| `min_blase_px` | Blasen bis zu dieser Länge verwerfen | px | 5 | gering |
| `randabstand_px` | Unit-Cells am Bildrand verwerfen | px | 2 | gering |
| `fragmente_verbinden` | durch Reflexionen zerteilte Blasen verbinden | – | `false` | **hoch**: mit `true` ändern sich 89 von 122 Videos, teils um 20 % (Kapitel 8) |
| `fragment_schwelle_rel` | Schein-Slug, wenn kürzer als dieser Anteil der typischen Slug-Länge | – | 0,7 | nur mit `fragmente_verbinden` |
| `fragment_min_slugs`, `fragment_klassen` | Mindestanzahl Slugs, Histogrammklassen für die typische Slug-Länge | – | 4, 10 | nur mit `fragmente_verbinden` |

## 3.5 Kanalmodell (`cfg.kanal`)

| Eintrag | Bedeutung | Einheit | Standard |
|---|---|---|---|
| `init_frames` | Frames für die Schätzung der Kanalwände | – | 10 |
| `stuetzabstand_px` | Abstand der Stützstellen | px | 20 |
| `min_gueltig_rel` | Mindestanteil gültiger Stützstellen je Frame | – | 0,3 |
| `breite_tol_rel`, `sprung_rel`, `kruemmung_rel`, `streuung_rel` | Schwellen für unplausible Stützstellen (Anteil der Kanalbreite) | – | 0,08, 0,05, 0,03, 0,04 |
| `min_hoehe_rel` | Mindesthöhe im Ersatzmodell (wenn die Schätzung scheitert) | – | 0,85 |

Wirkung: nur bei schwierigen Bildern (Spiegelungen an der Wand,
schwankende Beleuchtung). Prüfen mit der Live-Ansicht (rote Linien).

## 3.6 Tracking (`cfg.tracking`)

| Eintrag | Bedeutung | Einheit | Standard | Wirkung |
|---|---|---|---|---|
| `max_sprung_px` | größte Verschiebung je Frame | px | 50 | **begrenzt die messbare Geschwindigkeit** auf ≈ max_sprung_px · s · f (50 px · 0,055 mm/px · 200 1/s ≈ 0,55 m/s) |
| `rueckwaerts_px` | tolerierte Rückwärtsbewegung | px | 2 | gering |
| `min_frames` | Mindestanzahl Frames je Blase | – | 10 | mittel: kleiner → mehr, aber unsicherere Messpunkte |

## 3.7 Physik und Einlauflänge (`cfg.physik`, `cfg.einlauf`)

| Eintrag | Bedeutung | Einheit | Standard | Wirkung |
|---|---|---|---|---|
| `physik.bin_mm` | Bin-Breite (wird auf ceil(2 · L_B)/2 vergrößert, wenn kleiner als L_B) | mm | 4 | bestimmt Anzahl und Glättung der Bins |
| `physik.v_max_m_s` | größte plausible Geschwindigkeit | m/s | 5 | wirkt praktisch nicht (Tracking begrenzt stärker) |
| `physik.plateau_rel` | Referenzbereich für die stabile Messzone | Anteil der Bins | [0,20 0,80] | mittel |
| `physik.plateau_schwelle` | Bin gilt, wenn Anzahl ≥ Schwelle · Median | – | 0,50 | mittel: höher → kürzere Messzone |
| `einlauf.rho_kg_m3` | Dichte der kontinuierlichen Phase | kg/m³ | 1000 | verschiebt die Einlauflänge |
| `einlauf.mu_Pa_s` | Viskosität der kontinuierlichen Phase | Pa·s | 0,001 | verschiebt die Einlauflänge |
| `einlauf.faktor` | L_ein = faktor · Re · d_h | – | 0,05 | verschiebt die Einlauflänge |

## 3.8 Ausgabe, Plots, Anzeige, GUI

| Eintrag | Bedeutung | Standard |
|---|---|---|
| `abbildungen.exportieren` | Methodik-Abbildungen Abb1–9 eines Frames erzeugen | `false` |
| `abbildungen.frame` | Frame für die Abbildungen | 15 |
| `abbildungen.dpi` | Auflösung | 600 |
| `abbildungen.bemassung_px` | Höhe der Bemaßungslinie über der Blase [px] | 45 |
| `plots.sprache` | Beschriftung `'de'` oder `'en'` | `'de'` |
| `plots.breite_cm`, `plots.hoehe_cm` | Plotgröße [cm] | 16, 9 |
| `plots.formate` | Ausgabeformate | `{'png', 'pdf'}` |
| `plots.dpi` | Auflösung der PNG-Dateien | 300 |
| `plots.batch` | Verlaufsplots nach jedem Batch | `true` |
| `anzeige.live` | Live-Ansicht während der Auswertung | `false` (GUI und `run_Einzel`: an) |
| `anzeige.jedes_n_frame` | jedes wievielte Frame gezeigt wird | 10 |
| `anzeige.kalibrierung` | Kalibrierkontrolle zeigen | `false` |
| `gui.sens_schritt` | Schrittweite des Sensitivitäts-Sweeps im GUI-Batch | 0,05 |
