# 1 Installation

## 1.1 Installing MATLAB and the toolboxes

The program requires **MATLAB R2025a or newer** with four toolboxes:

| Toolbox | Used for |
|---|---|
| Image Processing Toolbox | image processing of the videos |
| Signal Processing Toolbox | detecting the ruler ticks |
| Statistics and Machine Learning Toolbox | means and scatter per bin |
| Parallel Computing Toolbox | batch evaluation on all processor cores (without it, the batch runs sequentially, only slower) |

**Installing MATLAB from scratch**

1. Sign in at <https://www.mathworks.com/downloads> with your MathWorks
   account. Create the account with your university e-mail address; this
   links it to the university's campus licence.
2. Download and start the Windows installer, sign in with the same account
   and select the licence.
3. In the **Select products** step, tick the four toolboxes from the table
   in addition to *MATLAB*. No other products are needed.
4. Finish the installation and start MATLAB.

**Adding toolboxes to an existing MATLAB installation**

1. In MATLAB, open **Home** → **Add-Ons** → **Get Add-Ons**.
2. Search for the toolbox name, e.g. "Image Processing Toolbox", and choose
   **Install**. Repeat for every missing toolbox.

**Checking**

```matlab
ver
```

lists the installed MATLAB version and all toolboxes. The four toolboxes
from the table must appear.

## 1.2 Downloading the program

The program is hosted on GitHub:
<https://github.com/Oxymoron9946/Bildauswertung-und-Analyse>
(branch `master`).

**Option A: as a ZIP file, no further software needed**

1. Open the page and click **Code** → **Download ZIP** (top right).
2. Extract the ZIP, e.g. to `C:\Messungen\Videoauswertung`. This folder is
   called the **project folder** below; it contains, among others,
   `config.m`, `run_Batch.m` and `Start_App.m`.

For a newer version, download the ZIP again and replace the folder. Back up
your own changes to `config.m` and `data/Laborbuch.csv` first.

**Option B: with Git (convenient for later updates)**

1. Install *Git for Windows* from <https://git-scm.com/download/win>
   (default settings are fine).
2. Open a command prompt, change to the desired parent folder and fetch the
   repository:

   ```bat
   cd C:\Messungen
   git clone https://github.com/Oxymoron9946/Bildauswertung-und-Analyse.git Videoauswertung
   ```

3. To get a newer version later (inside the project folder):

   ```bat
   cd C:\Messungen\Videoauswertung
   git pull
   ```

   If you changed `config.m` or the lab notebook locally, `git pull` only
   reports a conflict when the same file was also changed on GitHub.

## 1.3 Providing the measurement data

The measurement videos (several GB) are not part of the repository; they
are stored at the chair. Two options:

- **Copy them into the project folder:** place the measurement folders
  (e.g. `PTFE_1000_600`) directly in the project folder. Nothing else needs
  to be done.
- **Leave them where they are:** enter the folder that contains the
  measurement folders in `config.m`, e.g.

  ```matlab
  cfg.pfade.messdaten = 'D:\Messdaten\Taylor-Flow';
  ```

Structure of the measurement folders and the lab notebook: chapter 2.

## 1.4 First start

1. Start MATLAB and change to the project folder (address bar at the top
   or `cd C:\Messungen\Videoauswertung`).
2. Check the settings:

   ```matlab
   cfg = config();
   videoauswertung.kern.pruefe_Config(cfg)   % no output = everything fine
   ```

3. Evaluate a small measurement folder: enter the folder in `run_Batch.m`
   (default `PVC_1500_1150`, 15 videos, a few minutes) and run `run_Batch`.
   The results are then in `output/` (chapter 4).
4. Alternatively, start the user interface: `Start_App` (chapter 6).

The three entry points `run_Batch`, `run_Einzel` and `Start_App` find all
program parts themselves; no `addpath` is needed.

The program, its messages and its user interface are in German. This
manual quotes them verbatim and explains them in English.

## 1.5 Common errors

| Message | Cause | Remedy |
|---|---|---|
| `Unrecognized function or variable 'config'` | MATLAB is not in the project folder | change to the project folder or start `run_Batch`/`Start_App` |
| `Unable to resolve the name 'videoauswertung.kern…'` | as above | as above |
| `Laborbuch nicht gefunden unter: …` (lab notebook not found) | `cfg.pfade.laborbuch` is wrong | check the path in `config.m` |
| `Messordner nicht gefunden: …` (measurement folder not found) | wrong name in `run_Batch.m` | give it relative to `cfg.pfade.messdaten` or as an absolute path |
| `Keine passenden .avi Dateien unter …` (no matching .avi files) | wrong folder or different camera | check the folder; `cfg.video.dateimuster` |
| `Undefined function 'adaptthresh'` / `'findpeaks'` / `'grpstats'` | toolbox missing | install the toolbox (1.1) |
| batch very slow, no "Starting parallel pool" | Parallel Computing Toolbox missing | install it or accept the longer run time |
