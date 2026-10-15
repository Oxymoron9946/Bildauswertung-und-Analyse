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

**Spalten der Tabellen:** *Herkunft* nennt, woher der Wert stammt
(„Ausgangsstand“ = im Code von `0cf713b` fest eingetragen, unverändert
übernommen). *Wirkung* beschreibt, was eine Änderung bewirkt. Quantitativ
untersucht ist nur die Sensitivität (Abschnitt 3.4); bei allen anderen
Werten gilt: vor einer Änderung mit dem Regressionssatz vergleichen
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

## 3.2 Video und Kalibrierung

| Eintrag | Bedeutung | Einheit | Standard | Herkunft | Wirkung |
|---|---|---|---|---|---|
| `video.dateimuster` | Dateiname der Kamera-AVIs | – | `XSM-3520 Camera 0330_*.avi` | Ausgangsstand | andere Kamera → anpassen |
| `video.fps` | Bildrate, falls der Pfad kein `<n>fps` enthält | 1/s | 200 | Ausgangsstand | skaliert alle Geschwindigkeiten linear |
| `kalibrierung.ordnermuster` | Name der Kalibrierordner | – | `Kalibrierung_*` | Ausgangsstand | – |
| `kalibrierung.rasterweite_mm` | Abstand zweier Linealstriche | mm | 0,525 | Ausgangsstand (Lineal) | skaliert alle Längen und Geschwindigkeiten linear |
| `kalibrierung.suchbereich_rel` | vertikaler Suchstreifen für das Lineal | Anteil Bildhöhe | [0,30 0,80] | Ausgangsstand | Lineal muss darin liegen |
| `kalibrierung.band_oben_px`, `band_unten_px` | Band um die Linealzeile | px | 60, 15 | Ausgangsstand | gering |
| `kalibrierung.rand_px` | ignorierter Bildrand | px | 25 | Ausgangsstand | gering |
| `kalibrierung.glaettung_px` | Glättung des Helligkeitsprofils | px | 5 | Ausgangsstand | zu groß: Striche verschmelzen |
| `kalibrierung.prominenz_rel` | Mindesthöhe eines Strichs | Anteil Maximum | 0,10 | Ausgangsstand | zu groß: Striche fehlen |
| `kalibrierung.min_strichabstand_px` | Mindestabstand zweier Striche | px | 8 | Ausgangsstand | muss kleiner als der Strichabstand im Bild (≈ 9,6 px) sein |
| `kalibrierung.min_striche` | Mindestanzahl Striche | – | 10 | Ausgangsstand | darunter gilt die Kalibrierung als fehlgeschlagen |
| `kalibrierung.raster_toleranz_rel` | zulässige Abweichung vom Median-Strichabstand | – | 0,25 | Ausgangsstand | gering |

## 3.3 Laborbuch-Korrekturen (`cfg.laborbuch`)

| Eintrag | Bedeutung | Einheit | Standard | Herkunft |
|---|---|---|---|---|
| `co2_anteil_druck` | CO₂-Anteil für Druckkalibrierungen, unabhängig vom Laborbuch; `NaN` = Laborbuchwert verwenden | – | 0 | Fix F06 (Druckkalibrierungen laufen ohne CO₂, Laborbuch trägt 0,2 ein) |

## 3.4 Detektion (`cfg.detektion`)

| Eintrag | Bedeutung | Einheit | Standard | Herkunft | Wirkung |
|---|---|---|---|---|---|
| `sens` | Sensitivität der adaptiven Schwelle; Vektor = Sweep | – (0…1) | 0,95 | Ausgangsstand (Batch) | **hoch**: 0,85 statt 0,95 ändert die Mittelwerte je Video um bis zu 6 %, einzelne Bins um bis zu 100 % (Fix F03) |
| `clahe_kacheln`, `clahe_clip` | Kontrastausgleich (adapthisteq) | – | [4 8], 0,01 | Ausgangsstand | Beleuchtungsabhängig |
| `median_px` | Medianfilter | px | [3 3] | Ausgangsstand | gering |
| `close_hoehe_px`, `close_breite_px` | Schließen von Rissen in den Blasen | px | 5, 5 | Ausgangsstand | zu groß: Blasen und Slugs verschmelzen |
| `staub_px` | kleinste schwarze Störfläche im Slug | px² | 15 | Ausgangsstand | gering |
| `min_slug_px` | kleinste weiße Slug-Fläche nach dem Füllen | px² | 50 | Ausgangsstand | gering |
| `min_flaeche_px` | kleinste Objektfläche für die Kanalhöhe | px² | 100 | Ausgangsstand | gering |
| `band_halb_px` | halbe Breite des Bands um die Mittellinie | px | 2 | Ausgangsstand | mittel: breiter → mehr Störkanten |
| `strahl_max_px`, `strahl_anteil`, `strahl_min_px` | Suchweite der Kantenklassifizierung | px, –, px | 20, 0,8, 2 | Ausgangsstand | mittel |
| `abstand_ersatz_px` | Ersatz-Kantenabstand, wenn kein Median bestimmbar | px | 50 | Ausgangsstand | selten wirksam |
| `min_blase_px` | Blasen bis zu dieser Länge verwerfen | px | 5 | Ausgangsstand | gering |
| `randabstand_px` | Unit-Cells am Bildrand verwerfen | px | 2 | Ausgangsstand | gering |
| `fragmente_verbinden` | durch Reflexionen zerteilte Blasen verbinden | – | `false` | Fix F07, zurückgestellt | **hoch**: mit `true` ändern sich 89 von 122 Videos, teils um 20 % (Kapitel 8) |
| `fragment_schwelle_rel` | Schein-Slug, wenn kürzer als dieser Anteil der typischen Slug-Länge | – | 0,7 | lokaler Patch | nur mit `fragmente_verbinden` |
| `fragment_min_slugs`, `fragment_klassen` | Mindestanzahl Slugs, Histogrammklassen für die typische Slug-Länge | – | 4, 10 | lokaler Patch | nur mit `fragmente_verbinden` |

## 3.5 Kanalmodell (`cfg.kanal`)

| Eintrag | Bedeutung | Einheit | Standard | Herkunft |
|---|---|---|---|---|
| `init_frames` | Frames für die Schätzung der Kanalwände | – | 10 | Ausgangsstand |
| `stuetzabstand_px` | Abstand der Stützstellen | px | 20 | Ausgangsstand |
| `min_gueltig_rel` | Mindestanteil gültiger Stützstellen je Frame | – | 0,3 | Ausgangsstand |
| `breite_tol_rel`, `sprung_rel`, `kruemmung_rel`, `streuung_rel` | Schwellen für unplausible Stützstellen (Anteil der Kanalbreite) | – | 0,08, 0,05, 0,03, 0,04 | Ausgangsstand |
| `min_hoehe_rel` | Mindesthöhe im Ersatzmodell (wenn die Schätzung scheitert) | – | 0,85 | Ausgangsstand |

Wirkung: nur bei schwierigen Bildern (Spiegelungen an der Wand,
schwankende Beleuchtung). Prüfen mit der Live-Ansicht (rote Linien).

## 3.6 Tracking (`cfg.tracking`)

| Eintrag | Bedeutung | Einheit | Standard | Herkunft | Wirkung |
|---|---|---|---|---|---|
| `max_sprung_px` | größte Verschiebung je Frame | px | 50 | Ausgangsstand | **begrenzt die messbare Geschwindigkeit** auf ≈ max_sprung_px · s · f (50 px · 0,055 mm/px · 200 1/s ≈ 0,55 m/s) |
| `rueckwaerts_px` | tolerierte Rückwärtsbewegung | px | 2 | Ausgangsstand | gering |
| `min_frames` | Mindestanzahl Frames je Blase | – | 10 | Ausgangsstand | mittel: kleiner → mehr, aber unsicherere Messpunkte |

## 3.7 Physik und Einlauflänge (`cfg.physik`, `cfg.einlauf`)

| Eintrag | Bedeutung | Einheit | Standard | Herkunft | Wirkung |
|---|---|---|---|---|---|
| `physik.bin_mm` | Bin-Breite (wird auf ceil(2 · L_B)/2 vergrößert, wenn kleiner als L_B) | mm | 4 | Ausgangsstand | bestimmt Anzahl und Glättung der Bins |
| `physik.v_max_m_s` | größte plausible Geschwindigkeit | m/s | 5 | Ausgangsstand | wirkt praktisch nicht (Tracking begrenzt stärker) |
| `physik.plateau_rel` | Referenzbereich für die stabile Messzone | Anteil der Bins | [0,20 0,80] | Ausgangsstand | mittel |
| `physik.plateau_schwelle` | Bin gilt, wenn Anzahl ≥ Schwelle · Median | – | 0,50 | Ausgangsstand | mittel: höher → kürzere Messzone |
| `einlauf.rho_kg_m3` | Dichte der kontinuierlichen Phase | kg/m³ | 1000 | Ausgangsstand (Wasser) | verschiebt die Einlauflänge |
| `einlauf.mu_Pa_s` | Viskosität der kontinuierlichen Phase | Pa·s | 0,001 | Ausgangsstand (Wasser) | verschiebt die Einlauflänge |
| `einlauf.faktor` | L_ein = faktor · Re · d_h | – | 0,05 | Ausgangsstand (laminare Einlauflänge) | verschiebt die Einlauflänge |

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
