# 1 Installation

## 1.1 Voraussetzungen

| Software | Version | Wofür |
|---|---|---|
| MATLAB | R2025a oder neuer (entwickelt mit R2025b) | alles |
| Image Processing Toolbox | passend zu MATLAB | Bildverarbeitung (adaptthresh, regionprops, imreconstruct …) |
| Signal Processing Toolbox | passend zu MATLAB | Strichsuche auf dem Lineal (findpeaks) |
| Statistics and Machine Learning Toolbox | passend zu MATLAB | Mittelwerte je Bin (grpstats) |
| Parallel Computing Toolbox | passend zu MATLAB | Batch parallel über mehrere Kerne; ohne sie läuft der Batch nacheinander |

Die Liste stammt aus `matlab.codetools.requiredFilesAndProducts` über
alle Dateien des Pakets. Installierte Toolboxen zeigt `ver` an.

R2025a ist nötig, weil die Plots mit `theme(fig, 'light')` unabhängig vom
Desktop-Design hell gezeichnet werden.

Nur für das PDF-Handbuch (optional):

| Software | Wofür |
|---|---|
| Python 3.10 oder neuer | `docs/build_pdf.py` |
| `pypandoc_binary` (pip) | Markdown → LaTeX, bringt Pandoc mit |
| TeX-Distribution mit XeLaTeX (TeX Live oder MiKTeX) | PDF-Satz |

## 1.2 Einrichten

1. Repository klonen oder als ZIP entpacken, z. B. nach
   `C:\Messungen\Videoauswertung`.
2. Messordner (`PTFE_1000_600`, …) in diesen Ordner kopieren oder in
   `config.m` unter `cfg.pfade.messdaten` den Ordner eintragen, in dem sie
   liegen.
3. MATLAB starten, in den Projektordner wechseln und prüfen:

   ```matlab
   cfg = config();
   videoauswertung.kern.pruefe_Config(cfg)   % keine Ausgabe = in Ordnung
   ```

4. Tests ausführen (mit Videos ca. 15 min, ohne Videos unter 1 min):

   ```matlab
   run('tests/run_AllTests.m')
   ```

Es ist kein `addpath` nötig: Die Einstiege `run_Batch.m`, `run_Einzel.m`
und `Start_App.m` fügen den Projektordner selbst hinzu.

## 1.3 PDF-Handbuch bauen (optional)

```bat
python -m venv .venv-docs
.venv-docs\Scripts\pip install -r docs\requirements.txt
.venv-docs\Scripts\python docs\build_pdf.py
```

Ergebnis: `docs/Handbuch_Videoauswertung.pdf`.

## 1.4 Typische Fehler

| Meldung | Ursache | Abhilfe |
|---|---|---|
| `Unrecognized function or variable 'config'` | MATLAB steht nicht im Projektordner und der Einstieg wurde nicht benutzt | in den Projektordner wechseln oder `run_Batch`/`Start_App` starten |
| `Unable to resolve the name 'videoauswertung.kern…'` | wie oben | wie oben |
| `Laborbuch nicht gefunden unter: …` | `cfg.pfade.laborbuch` falsch | Pfad in `config.m` prüfen |
| `Messordner nicht gefunden: …` | Name in `run_Batch.m` falsch | relativ zu `cfg.pfade.messdaten` oder absolut angeben |
| `Keine passenden .avi Dateien unter …` | falscher Ordner oder andere Kamera | Ordner prüfen; `cfg.video.dateimuster` |
| `Undefined function 'adaptthresh'` / `'findpeaks'` / `'grpstats'` | Toolbox fehlt | Toolbox installieren (1.1) |
| Batch sehr langsam, kein „Starting parallel pool“ | Parallel Computing Toolbox fehlt | installieren oder in Kauf nehmen |
| Plots erscheinen dunkel | MATLAB älter als R2025a | MATLAB aktualisieren |
