# Videoauswertung Taylor-Flow

**Deutsch** · [English](#english)

[![Handbuch-PDF](https://github.com/Oxymoron9946/Bildauswertung-und-Analyse/actions/workflows/handbuch-pdf.yml/badge.svg)](https://github.com/Oxymoron9946/Bildauswertung-und-Analyse/actions/workflows/handbuch-pdf.yml)

MATLAB-Auswertung von Hochgeschwindigkeitsvideos eines Gas-Flüssig-Taylor-Flows
in Mikrokanälen. Aus jedem Video entstehen ortsaufgelöst entlang des Kanals:

- Blasengeschwindigkeit u_B [m/s]
- Blasen-, Slug- und Unit-Cell-Länge [mm]
- Längenanteil der Blase L_B/L_UC [-]

Die Ergebnisse werden in Bins entlang der Kanalposition gemittelt und je
Messreihe als CSV geschrieben, dazu Verlaufsplots je Einstellung. Bedienung
per Skript oder über eine Oberfläche; beide nutzen dieselben Funktionen und
dieselbe Einstellungsdatei `config.m`.

> **Handbuch:** [PDF deutsch](docs/Handbuch_Videoauswertung.pdf) ·
> [PDF English](docs/Handbuch_Videoauswertung_en.pdf) ·
> [alle Kapitel](docs/README.md) ·
> **[Handbuch bearbeiten](docs/HANDBUCH_BEARBEITEN.md)**
>
> **Weiterverarbeitung:** Die Ergebnisdateien `Auswertung_Masse_….csv` sind die
> Eingabe der [TaylorFlow-Auswertung](https://github.com/Oxymoron9946/TaylorFlow_Auswertung)
> (Druckprofil, CO2-Stoffmenge, kLa, Literaturmodelle).

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
englisch: [docs/Handbuch_Videoauswertung_en.pdf](docs/Handbuch_Videoauswertung_en.pdf)
(Kapitel in [docs/en/](docs/en/)). Beide PDFs werden bei jeder Änderung in
`docs/` automatisch neu gebaut; lokal mit `python docs/build_pdf.py` bzw.
`python docs/build_pdf.py en`.

**Handbuch ändern:** [docs/HANDBUCH_BEARBEITEN.md](docs/HANDBUCH_BEARBEITEN.md) –
im Browser, ohne Installation.

---

## English

MATLAB evaluation of high-speed videos of a gas–liquid Taylor flow in
microchannels. For every video it determines, resolved along the channel:

- bubble velocity u_B [m/s]
- bubble, slug and unit-cell length [mm]
- bubble length fraction L_B/L_UC [-]

The results are averaged in bins along the channel position and written as
CSV per measurement series, together with profile plots per setting. It runs
from scripts or from a graphical interface; both use the same functions and
the same settings file `config.m`.

> **Manual:** [PDF English](docs/Handbuch_Videoauswertung_en.pdf) ·
> [PDF Deutsch](docs/Handbuch_Videoauswertung.pdf) ·
> [all chapters](docs/README.md) ·
> **[Editing the manual](docs/en/EDITING_THE_MANUAL.md)**
>
> **Next step:** the result files `Auswertung_Masse_….csv` are the input of the
> [TaylorFlow evaluation](https://github.com/Oxymoron9946/TaylorFlow_Auswertung)
> (pressure profile, absorbed CO2, kLa, literature models).

### Quick start

1. Install **MATLAB R2025a or newer** with the Image Processing, Signal
   Processing, Statistics and Machine Learning and Parallel Computing
   toolboxes (details: [docs/en/01_installation.md](docs/en/01_installation.md)).
2. **Download the program:** on this page **Code → Download ZIP** and unzip,
   or `git clone https://github.com/Oxymoron9946/Bildauswertung-und-Analyse.git`.
3. Put the **measurement data** into the project folder, e.g.
   `PTFE_1000_600/…`, and keep one row per run in the lab book
   `data/Laborbuch.csv` ([docs/en/02_messdaten.md](docs/en/02_messdaten.md)).
4. Check the **settings** in `config.m`. Nothing needs to be changed for a
   first run ([docs/en/03_konfiguration.md](docs/en/03_konfiguration.md)).
5. **Evaluate** – in MATLAB, in the project folder:
   - all videos of a measurement folder: enter the folder in `run_Batch.m`, then `run_Batch`
   - a single video with live view: `run_Einzel`
   - with the user interface: `Start_App`
6. The **results** are in `output/`: CSV per setup in
   `Output_MassTransfer/` or `Output_PressureCalibration/`, plots in the
   subfolder `plots/` ([docs/en/04_auswertung.md](docs/en/04_auswertung.md)).

Tests: `run('tests/run_AllTests.m')` (about 15 min with videos).

### Folders

```
config.m               the only settings file
run_Batch.m            batch evaluation of a measurement folder
run_Einzel.m           single video with live view and plots
Start_App.m            user interface
+videoauswertung/
  +kern/               evaluation (calibration, detection, tracking, physics)
  +io/                 read lab book, write results
  +plots/              one function per plot, shared PlotStil
  +gui/                user interface (only calls +kern and +plots)
data/                  lab book (CSV, semicolon-separated)
tests/                 unit tests, GUI smoke test, regression test
docs/                  manual (Markdown and PDF), English version in docs/en/
tools/                 helper tools (result comparison, manual figures)
```

The measurement videos themselves (`Glaskanal/`, `PTFE_1000_600/`, …,
several GB) are not part of the repository.

### Manual

| Chapter | Content |
|---|---|
| [01 Installation](docs/en/01_installation.md) | MATLAB, toolboxes, common errors |
| [02 Measurement data](docs/en/02_messdaten.md) | folder structure, lab book, new measurement series |
| [03 Configuration](docs/en/03_konfiguration.md) | every entry in `config.m` |
| [04 Evaluation](docs/en/04_auswertung.md) | procedure, output files, column reference |
| [05 Plots](docs/en/05_plots.md) | every plot with example and call |
| [06 GUI](docs/en/06_gui.md) | operation, mapping to `config.m`, repeating a run |
| [07 Method](docs/en/07_methodik.md) | evaluation chain with equations |
| [08 Limitations](docs/en/08_grenzen.md) | validity, restrictions, data that cannot be evaluated |
| [09 Extending](docs/en/09_erweitern.md) | architecture, new plot, tests |

PDF: [docs/Handbuch_Videoauswertung_en.pdf](docs/Handbuch_Videoauswertung_en.pdf),
rebuilt automatically whenever anything in `docs/` changes; locally with
`python docs/build_pdf.py en`.

**Editing the manual:** [docs/en/EDITING_THE_MANUAL.md](docs/en/EDITING_THE_MANUAL.md) –
in the browser, nothing to install.
