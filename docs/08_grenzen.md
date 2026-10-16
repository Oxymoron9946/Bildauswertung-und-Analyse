# 8 Grenzen

## 8.1 Gültigkeitsbereich

Die Auswertung setzt voraus:

- **Taylor-Flow** mit abwechselnd Blase und Slug über die ganze Bildbreite.
  Blasenschwärme, Blasen ohne Slug dazwischen oder Ringströmung werden
  nicht sinnvoll erkannt.
- **Strömung von rechts nach links** im Bild. Bei umgekehrter Kamera
  werden Geschwindigkeiten negativ und verworfen.
- **Feste Kamera und Beleuchtung** während eines Videos: Das Kanalmodell
  wird aus den ersten 10 Frames geschätzt und danach nicht mehr angepasst.
- **Lineal mit 0,525 mm Strichabstand** im ersten Frame des
  Kalibriervideos, im mittleren Bildbereich (30–80 % der Bildhöhe).
- **Geschwindigkeiten unter 5 m/s** (`cfg.physik.v_max_m_s`) und
  Verschiebungen unter 50 px je Frame (`cfg.tracking.max_sprung_px`). Bei
  200 fps und rund 0,055 mm/px entspricht das etwa 0,55 m/s; schnellere
  Blasen erfordern eine höhere Bildrate oder einen größeren Wert.
- **Wasser als kontinuierliche Phase** für die Einlauflänge
  (`cfg.einlauf`).

## 8.2 Bekannte Einschränkungen

- **Bin-Breite variiert.** Ist die mittlere Blasenlänge größer als
  `cfg.physik.bin_mm`, wird die Bin-Breite auf ceil(2 · L_B)/2 mm
  vergrößert. Ergebnisse verschiedener Messreihen haben dann
  unterschiedliche Bin-Raster.
- **`VoidFraction` ist ein Längenverhältnis** L_B/L_UC, kein
  Volumenanteil; Form der Blasenkappen und Flüssigkeitsfilm sind nicht
  berücksichtigt.
- **Abhängigkeit von der Sensitivität.** Die adaptive Schwelle
  (`cfg.detektion.sens`) beeinflusst Blasenlängen merklich. Für neue
  Kanäle oder Beleuchtungen lohnt ein Sweep (z. B. 0.85:0.05:0.95) und der
  Vergleich der Plots.
- **Stabile Messzone.** Bins am Bildrand mit wenigen Messpunkten werden
  verworfen; bei kurzen Videos oder wenigen Blasen kann die Zone leer sein
  (Warnung „Keine stabile Messzone gefunden“, keine Zeilen für dieses Video).
- **Reflexionen.** Starke Lichtreflexe können eine Blase in zwei Teile
  zerlegen, die dann als zwei kurze Blasen gezählt werden. Die
  experimentelle Option `cfg.detektion.fragmente_verbinden` (Standard aus)
  verbindet solche Teile, verbindet in manchen Videos aber auch echte
  Blasen; vor Gebrauch mit der Live-Ansicht prüfen.

## 8.3 Nicht auswertbare Daten

- **`Glaskanal/Messungen`** (94 Videos, März 2026): altes Namensschema
  (`0,07_0,04_Position_1`) ohne Kalibriergruppe `Pos_<n>_Kal_<k>`, teils
  120 oder 500 fps. Der Batch überspringt diese Videos. Für eine
  Auswertung müssten die Ordner nach Kapitel 2 umbenannt und einer
  Kalibrierung zugeordnet werden.
- Zu diesen Altdaten gehört auch der doppelte Laborbuch-Eintrag
  `0.15_0.06_Position_1`.
