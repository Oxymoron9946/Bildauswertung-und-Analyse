# 4 Auswertung und Ergebnisse

## 4.1 Ablauf

```
Messordner ──► alle Messvideos finden (cfg.video.dateimuster, ohne Kalibrierordner)
                 │
                 ▼  je Video (parallel)
               Messlauf + Aufnahme aus dem Pfad ── Laborbuchzeile (Pflichtangaben)
               Kalibriervideo im Gruppenordner ── Maßstab mm/px
                 │
                 ▼  je Frame
               Blasen erkennen ── Blasen über Frames verfolgen
                 │
                 ▼  am Videoende
               Geschwindigkeit, Längen, Position ── Bins ── stabile Messzone
                 │
                 ▼  alle Videos
               CSV je Setup ── Verlaufsplots je Einstellung
```

Die Einzelauswertung (`run_Einzel`, GUI „Einzelvideo“) durchläuft
dieselbe Kette für ein Video und schreibt dieselben Spalten.

## 4.2 Ausgabedateien

Alle Ausgaben liegen unter `cfg.pfade.ausgabe` (Standard `output/`):

| Datei | Inhalt |
|---|---|
| `Output_MassTransfer/Auswertung_Masse_<Material>_<Form>_<Kanal>um_<Länge>cm_<CO2>molCO2_<Nadel>um.csv` | Batch, Stoffübergangsmessungen eines Setups |
| `Output_PressureCalibration/Auswertung_Druck_….csv` | Batch, Druckkalibrierungen eines Setups |
| `…/plots/Gas_<jG>_Liq_<jL>_<Material>_<Form>_<Kanal>um_Geschwindigkeit.png/.pdf` | Verlaufsplot u_B(x) je Einstellung |
| `…/plots/…_Blasenlaenge.png/.pdf` | Verlaufsplot L_B(x) je Einstellung |
| `Output_…/Analysis_<Mass/Pressure>_<Messlauf>_<Aufnahme>.csv` | Einzelauswertung eines Videos |
| `lauf_config_<Zeitstempel>.json` | vollständige Einstellungen des Laufs (Kapitel 6.4) |
| `abbildungen/Abb*.png` | Methodik-Abbildungen, nur bei `cfg.abbildungen.exportieren` |

Eine bestehende Datei gleichen Namens wird überschrieben.

## 4.3 Spaltenlexikon

Trennzeichen Semikolon, Dezimalpunkt. Eine Zeile ist ein Bin entlang des
Kanals für ein Video (und eine Sensitivität).

**Metadaten** (für alle Bins eines Videos gleich)

| Spalte | Bedeutung | Einheit | Quelle |
|---|---|---|---|
| `GasVelocity` | Leerrohrgeschwindigkeit Gas j_G | m/s | Ordnername |
| `LiquidVelocity` | Leerrohrgeschwindigkeit Flüssigkeit j_L | m/s | Ordnername |
| `CameraPosition` | Kameraposition | – | Ordnername |
| `Aufnahme` | Aufnahmeordner, z. B. `200fps_002` | – | Ordnername |
| `Material` | Kanalmaterial | – | Ordnername |
| `Geometrie` | Querschnitt: `R` rund, `Q` quadratisch | – | Ordnername |
| `Kanal_um` | Kanalmaß (Durchmesser bzw. Kantenlänge) | µm | Ordnername |
| `Nadel_um` | Innendurchmesser der Gasnadel | µm | Ordnername |
| `Reaktor_cm` | Reaktorlänge | cm | Laborbuch `Kanallaenge` |
| `Druck_Pa_Auslass` | Umgebungsdruck am Auslass | Pa | Laborbuch |
| `Temperatur_C` | Umgebungstemperatur | °C | Laborbuch |
| `CO2_Anteil` | CO₂-Anteil im Gas | – | Laborbuch (Druck: `cfg.laborbuch.co2_anteil_druck`) |
| `Messart` | `Massentransfer` oder `Druckkalibrierung` | – | Ordnername (`_Druck`) |
| `UsedSensitivity` | verwendete Sensitivität der Schwelle | – | `cfg.detektion.sens` |

**Ergebnisse je Bin**

| Spalte | Bedeutung | Einheit |
|---|---|---|
| `BinCenter_mm` | Mitte des Bins, Position im Reaktor ab Einlauf | mm |
| `GroupCount` | Anzahl Messpunkte im Bin (Blasen × Framepaare) | – |
| `mean_BubbleLength_mm`, `std_…` | Blasenlänge L_B, Mittel und Standardabweichung | mm |
| `mean_UnitCellLength_mm`, `std_…` | Unit-Cell-Länge L_UC | mm |
| `mean_SlugLength_mm`, `std_…` | Slug-Länge L_S = L_UC − L_B | mm |
| `mean_VoidFraction`, `std_…` | Längenanteil der Blase L_B/L_UC | – |
| `mean_Speed_m_s`, `std_…` | Blasengeschwindigkeit u_B | m/s |

Nur Bins innerhalb der stabilen Messzone erscheinen (Kapitel 7.5).

## 4.4 Protokoll lesen

Die Konsole (bzw. im Batch-Skript das MATLAB-Befehlsfenster) zeigt:

| Meldung | Bedeutung | Handlung |
|---|---|---|
| `Laborbuch geladen: N Einträge` | Laborbuch gefunden | – |
| `Starte parallele Batch-Auswertung für N Messvideos` | gefundene Videos | Anzahl plausibel? |
| `ÜBERSPRUNGEN: Der Videopfad enthält keinen Ordner "Pos_<n>_Kal_<k>"` | Ordnerstruktur passt nicht | Kapitel 2.1 |
| `ÜBERSPRUNGEN: Kein Kalibriervideo unter …` / `Mehrere Kalibriervideos unter …` | Kalibrierordner fehlt oder ist doppelt | Kapitel 2.1 |
| `ÜBERSPRUNGEN: Ordner "…" wurde im Laborbuch … nicht gefunden` | Laborbuchzeile fehlt | Kapitel 2.2 |
| `ÜBERSPRUNGEN: Im Laborbuch fehlt "…"` | Pflichtangabe leer | Laborbuch ergänzen |
| `ÜBERSPRUNGEN: Automatische Kalibrierung fehlgeschlagen` | Lineal nicht erkannt | Kalibriervideo prüfen (Kalibrierkontrolle, Kapitel 6) |
| `Keine stabile Messzone gefunden` | zu wenige Messpunkte | Video kürzer/unruhig; Sensitivität prüfen |
| `Kanalhöhe konnte nicht zuverlässig bestimmt werden` | einzelne Frames ohne genug Objekte | unkritisch, wenn selten |
| `ERFOLG: N Zeilen gespeichert in …` | Ergebnisdatei geschrieben | – |
