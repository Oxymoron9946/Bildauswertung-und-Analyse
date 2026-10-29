# Handbuch bearbeiten

English version: [en/EDITING_THE_MANUAL.md](en/EDITING_THE_MANUAL.md)

Das Handbuch besteht aus Textdateien (`docs/*.md`, Format *Markdown*). Das PDF
`docs/Handbuch_Videoauswertung.pdf` wird daraus **automatisch erzeugt**. Nur die
`.md`-Dateien bearbeiten, nie das PDF.

## Ändern – im Browser, ohne Installation

1. Auf GitHub im Repository den Ordner **docs** öffnen und das Kapitel anklicken
   (Liste unten). GitHub zeigt es fertig formatiert an.
2. Rechts oben auf den **Stift** (*Edit this file*) klicken.
3. Text ändern. Mit dem Reiter **Preview** das Ergebnis prüfen.
4. Grün **Commit changes…** → kurz beschreiben, was geändert wurde →
   **Commit changes**.
5. Nach etwa **3 Minuten** liegen die neuen PDFs (deutsch und englisch) im
   Ordner `docs`. Den Fortschritt zeigt der Reiter **Actions**:
   gelber Punkt = läuft, grüner Haken = fertig, rotes ✗ = Fehler (siehe unten).

Mehrere Kapitel nacheinander ändern ist kein Problem; das PDF wird danach
einfach noch einmal gebaut.

**Bild hinzufügen:** Ordner `docs/bilder` öffnen → **Add file → Upload
files** → Bild hochladen. Im Text einbinden mit
`![Bildunterschrift](bilder/name.png)`.

## Kapitel

| Datei | Kapitel |
|---|---|
| `01_installation.md` | 1 Installation |
| `02_messdaten.md` | 2 Messdaten |
| `03_konfiguration.md` | 3 Konfiguration |
| `04_auswertung.md` | 4 Auswertung und Ergebnisse |
| `05_plots.md` | 5 Plots |
| `06_gui.md` | 6 Bedienoberfläche |
| `07_methodik.md` | 7 Methodik |
| `08_grenzen.md` | 8 Grenzen |
| `09_erweitern.md` | 9 Erweitern |

Die englische Fassung steht in `docs/en/` mit denselben Dateinamen. Keine der beiden
Fassungen wird automatisch übersetzt: Eine Änderung bei Bedarf in der anderen
Sprache ebenfalls eintragen.

## Markdown in Kürze

| Schreibweise | Ergebnis |
|---|---|
| `## 2.3 Überschrift` | Abschnittsüberschrift (`#` Kapitel, `##` Abschnitt, `###` Unterabschnitt) |
| `**fett**`, `*kursiv*` | **fett**, *kursiv* |
| `- Punkt` bzw. `1. Punkt` | Aufzählung bzw. nummerierte Liste |
| `` `config.m` `` | Programmtext `config.m` |
| `[Text](https://…)` | Link |
| `![Unterschrift](bilder/x.png)` | Bild mit Bildunterschrift |
| `\| a \| b \|` | Tabellenzeile (Muster: vorhandene Tabellen kopieren) |

Eine **Leerzeile** trennt Absätze; ein einfacher Zeilenumbruch
wird ignoriert.

## Wenn etwas schiefgeht

- **Rotes ✗ unter Actions:** Lauf anklicken → Schritt *PDFs bauen* aufklappen;
  die letzten Zeilen nennen meist die Stelle im Text. Die zuletzt geänderte
  Datei korrigieren und erneut speichern. Das alte PDF bleibt so lange
  erhalten.
- **PDF von Hand neu bauen:** Actions → *Handbuch-PDF bauen* → **Run workflow**.
- **Neues Kapitel:** neue Datei `docs/NN_name.md` (und `docs/en/NN_name.md`) anlegen
  *und* ihren Namen in
  `docs/build_pdf.py` in die Liste `KAPITEL = [...]` eintragen, sonst fehlt
  sie im PDF.

## Optional: am eigenen Rechner

- **Anschauen und bearbeiten:** [VS Code](https://code.visualstudio.com) →
  Ordner `docs` öffnen → Kapitel öffnen → `Strg+K`, dann `V`: links Text,
  rechts die formatierte Vorschau.
- Wer mit Git arbeitet: vor dem Bearbeiten **Pull** ausführen, denn der
  automatische PDF-Bau legt nach jeder Änderung einen eigenen Commit an.
- PDF lokal bauen (braucht MiKTeX oder TeX Live und die Schrift DejaVu):
  `pip install -r docs/requirements.txt`, dann `python docs/build_pdf.py`
  bzw. `python docs/build_pdf.py en`.
