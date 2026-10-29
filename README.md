# Videoauswertung Taylor-Flow

MATLAB-Auswertung von Hochgeschwindigkeitsvideos eines Gas-Flüssig-Taylor-Flows
in Mikrokanälen. Aus jedem Video entstehen ortsaufgelöst entlang des Kanals:

- Blasengeschwindigkeit u_B [m/s]
- Blasen-, Slug- und Unit-Cell-Länge [mm]
- Längenanteil der Blase L_B/L_UC [-]

Die Ergebnisse werden in Bins entlang der Kanalposition gemittelt und je
Messreihe als CSV geschrieben, dazu Verlaufsplots je Einstellung. Bedienung
per Skript oder über eine Oberfläche; beide nutzen dieselben Funktionen und
dieselbe Einstellungsdatei `config.m`.

## Schnellstart

1. **MATLAB R2025a oder neuer** mit Image Processing, Signal Processing,
   Statistics and Machine Learning und Parallel Computing Toolbox
   installieren (Details: [docs/01_installation.md](docs/01_installation.md)).
2. **Programm herunterladen:** auf dieser Seite **Code → Download ZIP** und
   entpacken, oder
   `git clone https://github.com/Oxymoron9946/Bildauswertung-und-Analyse.git`.
3. **Messdaten** in den Projektordner legen, z. B. `PTFE_1000_600/…`, und im
   Laborbuch `data/Laborbuch.csv` je Messlauf eine Zeile pflegen
   ([docs/02_messdaten.md](docs/02_messdaten.md)).
4. **Einstellungen** prüfen: `config.m`. Für den ersten Lauf ist nichts zu
   ändern ([docs/03_konfiguration.md](docs/03_konfiguration.md)).
5. **Auswerten** – in MATLAB im Projektordner:
   - alle Videos eines Messordners: in `run_Batch.m` den Ordner eintragen, dann `run_Batch`
   - ein einzelnes Video mit Live-Ansicht: `run_Einzel`
   - mit Oberfläche: `Start_App`
6. **Ergebnisse** stehen in `output/`: CSV je Setup in
   `Output_MassTransfer/` bzw. `Output_PressureCalibration/`, Plots im
   Unterordner `plots/` ([docs/04_auswertung.md](docs/04_auswertung.md)).

Tests: `run('tests/run_AllTests.m')` (mit Videos ca. 15 min).

## Ordner

```
config.m               einzige Einstellungsdatei
run_Batch.m            Batch-Auswertung eines Messordners
run_Einzel.m           Einzelvideo mit Live-Ansicht und Plots
Start_App.m            Bedienoberfläche
+videoauswertung/
  +kern/               Auswertung (Kalibrierung, Erkennung, Tracking, Physik)
  +io/                 Laborbuch lesen, Ergebnisse schreiben
  +plots/              eine Funktion je Plot, gemeinsamer PlotStil
  +gui/                Oberfläche (ruft nur +kern und +plots auf)
data/                  Laborbuch (CSV, Semikolon)
tests/                 Einheitentests, GUI-Rauchtest, Regressionstest
docs/                  Handbuch (Markdown und PDF), englische Fassung in docs/en/
tools/                 Hilfswerkzeuge (Ergebnisvergleich, Handbuch-Abbildungen)
```

Die Messvideos selbst (`Glaskanal/`, `PTFE_1000_600/`, …, mehrere GB) sind
nicht im Repository.

## Handbuch

| Kapitel | Inhalt |
|---|---|
| [01 Installation](docs/01_installation.md) | MATLAB, Toolboxen, typische Fehler |
| [02 Messdaten](docs/02_messdaten.md) | Ordnerstruktur, Laborbuch, neue Messreihe |
| [03 Konfiguration](docs/03_konfiguration.md) | jeder Eintrag in `config.m` |
| [04 Auswertung](docs/04_auswertung.md) | Ablauf, Ausgabedateien, Spaltenlexikon |
| [05 Plots](docs/05_plots.md) | jeder Plot mit Beispiel und Aufruf |
| [06 GUI](docs/06_gui.md) | Bedienung, Zuordnung zu `config.m`, Lauf wiederholen |
| [07 Methodik](docs/07_methodik.md) | Auswertekette mit Formeln |
| [08 Grenzen](docs/08_grenzen.md) | Gültigkeit, Einschränkungen, nicht auswertbare Daten |
| [09 Erweitern](docs/09_erweitern.md) | Architektur, neuer Plot, Tests |

PDF: [docs/Handbuch_Videoauswertung.pdf](docs/Handbuch_Videoauswertung.pdf),
erzeugt mit `python docs/build_pdf.py`, bei jeder Änderung in `docs/`
automatisch neu gebaut. Handbuch ändern:
[docs/HANDBUCH_BEARBEITEN.md](docs/HANDBUCH_BEARBEITEN.md).

**English manual:** [docs/Handbuch_Videoauswertung_en.pdf](docs/Handbuch_Videoauswertung_en.pdf)
(chapters in [docs/en/](docs/en/), built with `python docs/build_pdf.py en`).
