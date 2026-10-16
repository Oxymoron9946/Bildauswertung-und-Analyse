# 7 Methodik

Dieses Kapitel beschreibt die Auswertekette vom Kamerabild bis zur
Ergebnistabelle. Alle Parameter stehen in `config.m`; die Namen in
Klammern verweisen auf die Einträge dort.

Die Strömung läuft im Bild **von rechts nach links**. Der rechte Bildrand
liegt im Reaktor bei der Position *Offset* aus dem Laborbuch.

## 7.1 Maßstab aus dem Kalibriervideo

Funktion: `videoauswertung.kern.kalibriere_Massstab`

Im ersten Frame des Kalibriervideos liegt ein Lineal mit einem
Strichabstand von 0,525 mm (`kalibrierung.rasterweite_mm`).

1. Im Suchstreifen zwischen 30 % und 80 % der Bildhöhe
   (`kalibrierung.suchbereich_rel`) wird die Zeile mit den meisten
   vertikalen Kanten (Sobel) gesucht. Sie liegt auf dem Lineal.
2. Über ein Band um diese Zeile wird das Helligkeitsprofil gemittelt,
   invertiert und geglättet. Seine Spitzen sind die Linealstriche.
3. Die längste Kette von Strichen mit gleichmäßigem Abstand (höchstens
   25 % Abweichung vom Median) ergibt

   L_px = x_letzter − x_erster und L_mm = n · 0,525 mm,

   also den Maßstab s = L_mm / L_px in mm/px.

Werden weniger als 10 Striche gefunden (`kalibrierung.min_striche`),
bricht die Auswertung des Videos ab.

## 7.2 Blasenerkennung je Frame

Funktion: `videoauswertung.kern.erkenne_Blasen`

1. **Kontrast und Binarisierung.** Kontrastausgleich (CLAHE) und
   Medianfilter, danach eine adaptive Schwelle mit der Sensitivität
   `detektion.sens`. Kleine Risse in den Blasen werden mit einem
   morphologischen Schließen (5 px × 5 px) geschlossen.
2. **Kanalwände.** In den ersten 10 Frames (`kanal.init_frames`) werden
   obere und untere Wand an Stützstellen im Abstand von 20 px geschätzt.
   Danach gilt der Median als festes Kanalmodell. Unplausible Stützstellen
   (Breite, Sprung, Krümmung, Streuung über die Frames) werden aus der
   Gegenwand oder durch Interpolation ersetzt. Die Mittellinie liegt
   zwischen beiden Wänden.
3. **Kanten auf der Mittellinie.** Jeder schwarze Abschnitt auf der
   Mittellinie ist eine Kante zwischen Blase und Slug. Für jede Kante
   werden links und rechts senkrechte Strahlen bis zum nächsten schwarzen
   Pixel geführt. Ist der freie Weg rechts kürzer, ist die Kante nach
   links gekrümmt: linke Kante einer Blase (Blasennase). Ist er links
   kürzer, ist es die linke Kante eines Slugs.
4. **Abwechselnde Kantentypen.** Im Taylor-Flow wechseln sich Blasen- und
   Slugkanten ab. Unentschiedene Kanten erhalten den Gegentyp des
   Nachbarn. Folgen zwei gleiche Typen aufeinander, wird die Kante
   entfernt, deren Wegfall den typischen Abstandsrhythmus besser herstellt.
5. **Füllen der Blasen.** Von Saatpunkten neben den Kanten aus füllt ein
   Region-Growing die Blasen; die Kantenspalten begrenzen das Wachstum.
6. **Blasen und Unit-Cells.** Schwarze Abschnitte auf der Mittellinie im
   gefüllten Bild sind Blasen (mindestens 6 px lang, nicht am Bildrand).
   Eine Unit-Cell reicht von der Nase einer Blase bis zur Nase der
   stromauf folgenden Blase; sie umfasst also eine Blase und den Slug
   dahinter.
7. **Optional: Fragmente verbinden** (`detektion.fragmente_verbinden`,
   Standard aus). Ein Schein-Slug, der kürzer ist als 0,7 × die typische
   Slug-Länge des Frames, gilt als Reflexion; die beiden Blasenteile
   werden verbunden. Siehe Kapitel 8 zur Wirkung.

Die Abbildungen Abb1 bis Abb9 (`abbildungen.exportieren = true`) zeigen
diese Schritte für ein Frame.

## 7.3 Zuordnung über die Frames

Funktion: `videoauswertung.kern.verfolge_Blasen`

Eine Blase übernimmt die Nummer der Blase aus dem Vorframe, die den
kleinsten plausiblen Weg stromab zurückgelegt hat: zwischen −2 px
(Rauschen, `tracking.rueckwaerts_px`) und 50 px (`tracking.max_sprung_px`).
Ohne Treffer erhält sie eine neue Nummer. Blasen, die in weniger als
10 Frames gefunden wurden (`tracking.min_frames`), werden verworfen.

## 7.4 Geschwindigkeit, Längen und Position

Funktion: `videoauswertung.kern.berechne_Physik`

Zwischen zwei Frames i und i+1 einer Blase gilt

    u_B = −(x_{i+1} − x_i) · s · f / 1000      [m/s]

mit dem Maßstab s [mm/px] und der Bildrate f [1/s]. Nur Werte mit
0 < u_B < 5 m/s (`physik.v_max_m_s`) werden behalten. Längen und Position
sind Mittelwerte beider Frames:

- Blasenlänge L_B, Unit-Cell-Länge L_UC, Slug-Länge L_S = L_UC − L_B
- Längenanteil der Blase ε = L_B / L_UC (Spalte `VoidFraction`; ein
  Längen-, kein Volumenverhältnis)
- Position im Reaktor x = Offset + (Bildbreite − x_px) · s, mit x_px der
  Mitte der gemessenen Blase

Geschwindigkeit und Position gehören zu benachbarten Blasen derselben
Unit-Cell: verfolgt wird die stromauf liegende Blase, gemessen (Länge,
Position) die stromab liegende. Da alle Blasen einer Unit-Cell-Kette mit
derselben Geschwindigkeit laufen, ist das gleichwertig.

Messpunkte vor der hydrodynamischen Einlauflänge werden verworfen:

    Re = ρ · (j_G + j_L) · d_h / μ,   L_ein = 0,05 · Re · d_h

mit ρ = 1000 kg/m³ und μ = 1 mPa·s (Wasser, `einlauf.*`), den
Leerrohrgeschwindigkeiten j_G und j_L und dem Kanalmaß d_h aus dem
Ordnernamen.

## 7.5 Bins und stabile Messzone

Die Positionen werden in Bins der Breite `physik.bin_mm` (4 mm) eingeteilt.
Ist die mittlere Blasenlänge größer als die Bin-Breite, wird die Breite
auf ceil(2 · L_B)/2 mm vergrößert, damit jedes Bin genug Messpunkte
enthält. Die Bin-Breite kann sich deshalb zwischen Messreihen
unterscheiden.

Am Bildrand treten Blasen ein und aus; dort ist die Erkennung unsicher.
Als stabile Messzone gilt der längste zusammenhängende Bereich von Bins,
die mindestens 50 % (`physik.plateau_schwelle`) des Medians der
Messpunktanzahl in den mittleren 60 % der Bins (`physik.plateau_rel`)
erreichen. Nur Bins in dieser Zone erscheinen in der Ergebnistabelle,
jeweils mit Mittelwert, Standardabweichung und Anzahl.
