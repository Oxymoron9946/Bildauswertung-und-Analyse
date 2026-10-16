# 1 Installation

## 1.1 MATLAB und Toolboxen installieren

Benötigt wird **MATLAB R2025a oder neuer** mit vier Toolboxen:

| Toolbox | Wofür |
|---|---|
| Image Processing Toolbox | Bildverarbeitung der Videos |
| Signal Processing Toolbox | Strichsuche auf dem Lineal |
| Statistics and Machine Learning Toolbox | Mittelwerte und Streuung je Bin |
| Parallel Computing Toolbox | Batch parallel auf allen Prozessorkernen (ohne sie läuft der Batch nacheinander, nur langsamer) |

**MATLAB neu installieren**

1. Auf <https://www.mathworks.com/downloads> mit dem MathWorks-Konto
   anmelden. Das Konto mit der Hochschul-E-Mail-Adresse anlegen; darüber
   wird die Campus-Lizenz der Hochschule zugeordnet.
2. Den Installer für Windows herunterladen und starten, mit demselben Konto
   anmelden und die Lizenz auswählen.
3. Im Schritt **Produkte auswählen** neben *MATLAB* die vier Toolboxen aus
   der Tabelle anhaken. Alle anderen Produkte werden nicht gebraucht.
4. Installation abschließen und MATLAB starten.

**Toolboxen zu einer vorhandenen MATLAB-Installation hinzufügen**

1. In MATLAB auf der Registerkarte **Home** → **Add-Ons** → **Get Add-Ons**
   (bzw. *Add-Ons holen*) öffnen.
2. Nach dem Namen der Toolbox suchen, z. B. „Image Processing Toolbox“, und
   **Install** wählen. Für jede fehlende Toolbox wiederholen.

**Prüfen**

```matlab
ver
```

listet die installierte MATLAB-Version und alle Toolboxen. Die vier
Toolboxen aus der Tabelle müssen darin vorkommen.

## 1.2 Programm herunterladen

Das Programm liegt auf GitHub:
<https://github.com/Oxymoron9946/Bildauswertung-und-Analyse>
(Branch `master`).

**Variante A: als ZIP, ohne weitere Software**

1. Die Seite öffnen, oben rechts auf **Code** → **Download ZIP** klicken.
2. Das ZIP entpacken, z. B. nach `C:\Messungen\Videoauswertung`. Dieser
   Ordner ist im Folgenden der **Projektordner**; er enthält u. a.
   `config.m`, `run_Batch.m` und `Start_App.m`.

Für eine neuere Version das ZIP erneut herunterladen und den Ordner
ersetzen. Eigene Änderungen an `config.m` und `data/Laborbuch.csv` vorher
sichern.

**Variante B: mit Git (bequem für spätere Aktualisierungen)**

1. *Git for Windows* von <https://git-scm.com/download/win> installieren
   (Standardeinstellungen genügen).
2. Die Eingabeaufforderung öffnen, in den gewünschten Elternordner wechseln
   und das Repository holen:

   ```bat
   cd C:\Messungen
   git clone https://github.com/Oxymoron9946/Bildauswertung-und-Analyse.git Videoauswertung
   ```

3. Später eine neue Version holen (im Projektordner):

   ```bat
   cd C:\Messungen\Videoauswertung
   git pull
   ```

   Hat man `config.m` oder das Laborbuch lokal geändert, meldet `git pull`
   einen Konflikt nur dann, wenn dieselbe Datei auch auf GitHub geändert
   wurde.

## 1.3 Messdaten bereitstellen

Die Messvideos (mehrere GB) sind nicht im Repository; sie liegen am
Lehrstuhl. Zwei Möglichkeiten:

- **In den Projektordner kopieren:** die Messordner (z. B.
  `PTFE_1000_600`) direkt in den Projektordner legen. Mehr ist nicht zu tun.
- **Am Ort lassen:** in `config.m` den Ordner eintragen, in dem die
  Messordner liegen, z. B.

  ```matlab
  cfg.pfade.messdaten = 'D:\Messdaten\Taylor-Flow';
  ```

Aufbau der Messordner und Laborbuch: Kapitel 2.

## 1.4 Erster Start

1. MATLAB starten und in den Projektordner wechseln (Ordnerleiste oben oder
   `cd C:\Messungen\Videoauswertung`).
2. Einstellungen prüfen:

   ```matlab
   cfg = config();
   videoauswertung.kern.pruefe_Config(cfg)   % keine Ausgabe = in Ordnung
   ```

3. Einen kleinen Messordner auswerten: in `run_Batch.m` den Messordner
   eintragen (Voreinstellung `PVC_1500_1150`, 15 Videos, wenige Minuten) und
   `run_Batch` ausführen. Die Ergebnisse stehen danach in `output/`
   (Kapitel 4).
4. Alternativ die Oberfläche starten: `Start_App` (Kapitel 6).

Die drei Einstiege `run_Batch`, `run_Einzel` und `Start_App` finden alle
Programmteile selbst; ein `addpath` ist nicht nötig.

## 1.5 Typische Fehler

| Meldung | Ursache | Abhilfe |
|---|---|---|
| `Unrecognized function or variable 'config'` | MATLAB steht nicht im Projektordner | in den Projektordner wechseln oder `run_Batch`/`Start_App` starten |
| `Unable to resolve the name 'videoauswertung.kern…'` | wie oben | wie oben |
| `Laborbuch nicht gefunden unter: …` | `cfg.pfade.laborbuch` falsch | Pfad in `config.m` prüfen |
| `Messordner nicht gefunden: …` | Name in `run_Batch.m` falsch | relativ zu `cfg.pfade.messdaten` oder absolut angeben |
| `Keine passenden .avi Dateien unter …` | falscher Ordner oder andere Kamera | Ordner prüfen; `cfg.video.dateimuster` |
| `Undefined function 'adaptthresh'` / `'findpeaks'` / `'grpstats'` | Toolbox fehlt | Toolbox installieren (1.1) |
| Batch sehr langsam, kein „Starting parallel pool“ | Parallel Computing Toolbox fehlt | installieren oder in Kauf nehmen |
