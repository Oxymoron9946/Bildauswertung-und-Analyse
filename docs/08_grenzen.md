# 8 Grenzen und offene Punkte

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
  unterschiedliche Bin-Raster (Befund F05, bewusst beibehalten).
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
- **Reflexionen.** Starke Lichtreflexe können Blasen zerteilen. Die
  Fragmentverbindung (`cfg.detektion.fragmente_verbinden`) gleicht das bei
  regelmäßigem Slug-Abstand aus, nicht aber bei sehr unregelmäßigem Flow.

## 8.3 Nicht auswertbare Daten

- **`Glaskanal/Messungen`** (94 Videos, März 2026): altes Namensschema
  (`0,07_0,04_Position_1`) ohne Kalibriergruppe `Pos_<n>_Kal_<k>`, teils
  120 oder 500 fps. Der Batch überspringt diese Videos. Für eine
  Auswertung müssten die Ordner nach Kapitel 2 umbenannt und einer
  Kalibrierung zugeordnet werden.
- Doppelter Laborbuch-Schlüssel `0.15_0.06_Position_1` (gehört zu diesen
  Altdaten, Befund F09).

## 8.4 Offene Punkte

- **Fragmentverbindung (F07).** Reflexionen zerteilen manche Blasen. Die
  Option `cfg.detektion.fragmente_verbinden` hilft in einigen Videos
  deutlich, verbindet in anderen aber echte Blasen und ist deshalb
  standardmäßig aus. Ein besseres Kriterium wäre z. B., nur zu verbinden,
  wenn die Gesamtlänge zur typischen Blasenlänge des Frames passt.
- **Geschwindigkeitsgrenze des Trackings.** `cfg.tracking.max_sprung_px`
  (50 px) begrenzt die messbare Geschwindigkeit bei 200 fps auf etwa
  0,55 m/s. Für schnellere Strömungen erhöhen und mit dem Regressionssatz
  prüfen.
- **Altdaten Glaskanal/Messungen** (8.3) sind nicht ausgewertet.
- **Laborbuch als Excel-Datei.** Neben `data/Laborbuch.csv` liegt
  `data/Laborbuch.xlsx`; gelesen wird nur die CSV. Wird die Excel-Datei
  gepflegt, muss die CSV nach jeder Änderung neu exportiert werden
  (Semikolon, Dezimalpunkt).
