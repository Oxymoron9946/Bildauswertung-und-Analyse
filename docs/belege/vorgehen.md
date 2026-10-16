# Übergabe einer Auswertungssoftware an den Betreuer: Vorgehen und Ziele

Diese Vorlage fasst zusammen, wie die TaylorFlow-Auswertung
(`Auswertung\TaylorFlow_Auswertung`) für die Übergabe aufbereitet wurde. Sie
dient als Arbeitsauftrag für ein zweites Skript. Ein Unterschied gegenüber
TaylorFlow: **Beim zweiten Skript bleibt die GUI erhalten.** Die betroffenen
Stellen sind mit **[GUI]** markiert.

---

## 1 Ziele

1. **Übergabefähig:** Der Betreuer wertet damit selbstständig neue, ähnlich
   aufgebaute Messreihen aus, ohne den Code zu kennen.
2. **Schlank:** Es kommen nur die ausgewählten Funktionen und Plots mit.
   Diagnose-Skripte, Backups, Prompts, alte Varianten und toter Code bleiben im
   Archiv.
3. **Einstellbar an einer Stelle:**
   - Eine zentrale `config.py` legt Pfade, Parameter, Plot-Auswahl und Stil
     fest.
   - Jeder Plot lässt sich auch per Code erzeugen.
   - **[GUI]** Die GUI ist eine Bedienoberfläche über denselben Funktionen.
     Was in der GUI geht, geht auch per Skript, und umgekehrt.
4. **Nachvollziehbar und unverändert in den Zahlen:**
   - Das Aufräumen ändert keine Ergebnisse. Jede Ausgabe ist bit-identisch zur
     Baseline.
   - Fixes, die Zahlen ändern, kommen nur einzeln mit Vorher/Nachher-Bericht
     und nach Freigabe.
5. **Dokumentiert:** Markdown im Repo und ein PDF-Handbuch auf Deutsch. Plots
   werden auf Deutsch und Englisch beschriftet.
6. **Archiv bleibt erhalten:** Das alte Repo wird nicht verändert, sondern
   getaggt. Das neue Repo entsteht daneben.

---

## 2 Arbeitsprinzipien

- **Erst kartieren, dann löschen.** Gestrichen wird erst nach der Auswahl durch
  den User am Gate (Phase 1).
- **Baseline vor jeder Änderung:**
  - Alle Ausgabedateien des Ausgangsstands werden eingefroren.
  - Ein Regressionstest vergleicht nach jedem Schritt gegen diese Referenz.
- **Ein Commit je Schritt.** Nach jedem Commit laufen die Tests.
- **Zahlenrelevante Fehler** werden gesammelt und einzeln vorgelegt, mit
  Vorher/Nachher-Tabelle (Median und Maximum der Abweichung). Nach der
  Freigabe werden die Referenz und das CHANGELOG aktualisiert. Belege kommen
  nach `docs/belege/`.
- **Kleine, sichere Fixes ohne Zahlenwirkung** (Pfade, Imports, Abstürze)
  dürfen direkt behoben werden. Sie werden im CHANGELOG vermerkt.
- **Kein Push, kein Remote-Repo und keine Änderung an `main` ohne Rückfrage.**
- **Lokale Änderungen** werden vor dem Verwerfen als Patch nach `_archiv\`
  gesichert. Es wird nichts gelöscht, sondern verschoben.

---

## 3 Ablauf

### Phase 0: Stand sichern und synchronisieren

1. Den lokalen Diff als Patch sichern. Sync-Konflikte und Fremddateien nach
   `_archiv\` verschieben.
2. Lokale Änderungen verwerfen und `git fetch`. Der User wählt den
   Basis-Branch.
3. Eine Baseline erzeugen: Die Ausgaben des gesamten Datensatzes kommen nach
   `_archiv\baseline_<commit>\`.
4. Das alte Repo lokal mit einem Archiv-Tag versehen. Ob der Tag gepusht
   wird, fragt man vorher.

### Phase 1: Kartierung und Katalog (Gate)

1. **Kartierung:**
   - Alle Module und Funktionen mit Aufrufern erfassen.
   - Tot, doppelt oder defekt markieren.
   - Verstreute Logik aufzeigen, z. B. Ausschlüsse an mehreren Stellen oder
     dieselbe Berechnung mehrfach.
   - Hartkodierte Pfade und Schwellwerte sowie Umgebungsvariablen-Hooks
     notieren.
2. **Plot-Katalog:**
   - Jeden erzeugbaren Plot einmal mit Beispieldaten rendern.
   - Daraus ein privates HTML-Artifact bauen. Je Eintrag: Bild, Inhalt,
     Quelle (Datei:Funktion), Eingangsdaten, Status, Empfehlung.
   - Die Auswahl erfolgt per Klick, gespeichert in der Artifact-Datenbank.
3. **Weitere Abschnitte im Katalog:**
   - Rechenfunktionen und Module
   - Ausgabespalten
   - Teilsysteme
   - Diagnose-Skripte
   - gefundene zahlenrelevante Fehler mit dem Vorschlag beheben oder nur
     dokumentieren
4. **[GUI] Zusätzlicher Katalog-Abschnitt für die GUI:**
   - Jeden Tab, Dialog und Button mit Screenshot erfassen.
   - Festhalten, welche Funktion dahinter steckt.
   - Festhalten, welche Logik **nur** in der GUI liegt, z. B. Auswahl, Presets
     oder Exportlayout.
   - Empfehlung je Element: behalten, zusammenführen oder streichen.
5. **⏸ Gate:** Der User hakt ab, was mitkommt. Erst danach geht es weiter.

### Phase 2: Neues, schlankes Repo

Das Repo entsteht neben dem alten mit eigenem `git init`. Zielstruktur:

```
config.py              einzige Einstellungsdatei (Pfade, Parameter, Plots, Stil)
<einstieg>.py          ein Skript je Aufgabe, liest config.py
gui.py                 [GUI] Startpunkt der Oberfläche
<paket>/
  einlesen.py, …       Rechenkern, importiert nichts aus der GUI
  plots/               eine Implementierung je Plot: plot_x(daten, stil, ...) -> Figure
  gui/                 [GUI] nur Oberfläche, ruft Kernfunktionen auf
config/*.yaml          z. B. Ausschlüsse mit Begründung, eigene Modelle
data/raw/              Bestandsdaten
tests/                 Einheitentests + Regressionstest gegen tests/referenz/
docs/                  01…NN_*.md, CHANGELOG.md, bilder/, belege/, build_pdf.py
requirements.txt
```

**Schritte:**

1. Referenz nach `tests/referenz/` legen und den Regressionstest schreiben.
2. Den Kern übernehmen:
   - nur Paket-Imports, keine `sys.path`-Hacks
   - kein `mkdir` beim Import
   - alle Pfade aus `config.py`, nichts abhängig vom Arbeitsverzeichnis
3. Toten Code, Umgebungsvariablen-Hooks, Varianten und gestrichene
   Ausgabespalten entfernen.
4. Verstreute Logik zusammenführen, z. B. Ausschlüsse in einer YAML-Datei mit
   Begründungsfeld.
5. Lange Funktionen in benannte Schritte zerlegen. Hartkodierte Schwellwerte
   werden zu benannten Parametern in `config.py`. Docstrings im NumPy-Stil, auf
   Deutsch, mit Einheiten.
6. Eindeutige Schlüssel für Messreihen festlegen, damit neue Messreihen keine
   Kollision erzeugen. Unbekannte Werte führen zu einem Fehler, nicht zu einem
   stillen Standardwert.
7. Plots neu aufsetzen: nur die ausgewählten, eine Implementierung je Plot,
   gemeinsamer `PlotStil` (Größe in cm, Sprache de/en, Formate, dpi).
8. Die gefundenen zahlenrelevanten Fixes einzeln nach Freigabe umsetzen.
9. **[GUI] GUI anbinden:**
   - **Trennung:** Der Kern darf `tkinter`, `PyQt` usw. nicht importieren. Die
     GUI ruft nur Kernfunktionen auf. Logik, die bisher nur in der GUI lag,
     wandert in den Kern oder in `config.py`.
   - **Startwerte:** Die GUI liest ihre Startwerte aus `config.py`. Was der
     Betreuer in der GUI einstellt, wird nach Möglichkeit sichtbar
     protokolliert oder exportiert, damit sich ein Lauf per Skript
     reproduzieren lässt.
   - **Abläufe:** GUI und Skript nutzen denselben Ablauf. Im Regressionstest
     wird geprüft, dass beide identische Ergebnisse liefern.
   - **Bedienung:** Gestrichene Funktionen verschwinden auch aus der GUI. Es
     bleiben keine toten Buttons stehen. Fehler aus dem Kern werden in der GUI
     als Meldung angezeigt und nicht verschluckt.
   - **Rauchtest:** Die GUI muss sich ohne Absturz starten und wieder
     schließen lassen, z. B. ein pytest mit Fenster, das sofort zerstört wird.

### Phase 3: Dokumentation

Zielgruppe ist der Betreuer: ein Fachmann für Verfahrenstechnik, der den Code
nicht kennt. Kapitelvorlage, angelehnt an TaylorFlow:

| Datei | Inhalt |
|---|---|
| `README.md` | Zweck, Schnellstart in 5 Schritten, Ordnerübersicht |
| `01_installation` | Python, venv, Abhängigkeiten, typische Fehler |
| `02_messdaten` | Dateinamenskonvention, Pflichtspalten mit Einheit, neue Messreihe hinzufügen, Ausschlüsse pflegen |
| `03_konfiguration` | **Jeder** Eintrag in `config.py`: Bedeutung, Einheit, Standardwert, Herkunft, Sensitivität |
| `04_auswertung` | Ablaufdiagramm, Ausgabedateien, Spaltenlexikon, Protokoll lesen |
| `05_plots` | Je Plot: Beispielbild, Aussage, Aufruf über config und per Python |
| **[GUI]** `0x_gui` | Bedienung Schritt für Schritt mit Screenshots; Zuordnung GUI-Element → config-Eintrag/Funktion; wie man einen GUI-Lauf per Skript wiederholt |
| `06_methodik` | Modellkette mit Formeln, ohne Entwicklungshistorie |
| `07_grenzen` | Gültigkeitsbereiche, bekannte Einschränkungen, offene Punkte |
| `08_erweitern` | Architektur, neuen Plot oder neues Modell ergänzen, Tests ausführen |
| Sonderkapitel | Teilsysteme in eigene Kapitel, als „nicht unmittelbar genutzt“ markieren, wenn zutreffend |
| `CHANGELOG.md` | Versionshistorie und alle freigegebenen Fixes mit Wirkung |

Das PDF-Handbuch baut `docs/build_pdf.py` mit `pypandoc_binary` und XeLaTeX.
Es enthält ein Titelblatt, ein Inhaltsverzeichnis und eingebettete Bilder.

---

## 4 Verifikation vor der Übergabe

- **Tests:** `pytest` ist grün, der Regressionstest eingeschlossen.
- **Zahlenwerte:** Alle behaltenen Spalten sind bit-gleich zur Baseline. Die
  einzige Ausnahme sind freigegebene Fixes mit Beleg.
- **Frischer Klon:** In einer neuen venv nur nach README installieren. Danach
  laufen alle Skripte fehlerfrei. **[GUI]** Auch die GUI startet und führt
  einen vollständigen Lauf durch.
- **Doku-Probe:** Eine Rohdatei als „neue Messreihe“ umbenennen und genau nach
  `02_messdaten` einbinden und auswerten.
- **Plots:** Die neu erzeugten Bilder visuell mit dem Katalog vergleichen.
- **PDF:** Baut ohne Fehler; Inhaltsverzeichnis und Bilder sind vorhanden.
- **Abschlussbericht** an den User mit:
  - Stand
  - offenen Entscheidungen, etwa Push, Remote-Repo und nicht umgesetzte Fixes
  - Kapiteln, die er fachlich gegenlesen sollte

---

## 5 Vorab mit dem User zu klären

1. Wo liegt das Skript, und welcher Branch oder Stand ist die Basis? Gibt es
   lokale Änderungen?
2. Neues Repo oder Aufräumen im bestehenden?
3. **[GUI]** Welches GUI-Framework wird verwendet? Bleibt die GUI vollständig,
   oder wird sie auf die ausgewählten Funktionen reduziert? Soll die GUI
   Einstellungen speichern können, z. B. als YAML/JSON neben `config.py`?
4. Welche Teilsysteme oder Kenngrößen fallen von vornherein weg (wie beim
   ersten Projekt der gewichtete kLa)?
5. Doku-Format und Sprache: Markdown plus PDF auf Deutsch, Plots auf Deutsch
   und Englisch?
6. Gemeinsame Teile mit TaylorFlow, z. B. Stoffdaten oder Plotstil: kopieren
   oder als gemeinsames Paket nutzen?

---

## 6 Erfahrungen aus dem ersten Durchlauf

- **Dateien schreiben:** Unter Windows Dateien nicht mit PowerShell
  `Get-/Set-Content` umschreiben, das erzeugt Mojibake. Stattdessen das
  Edit/Write-Tool oder `[IO.File]::WriteAllText(..., UTF8)` verwenden.
- **Bit-Gleichheit bei CSV:** Die CSV mit `float_precision="round_trip"`
  lesen. Sonst entstehen Abweichungen von 1 ULP.
- **pandas 3:** Textspalten vor Vergleichen mit `fillna("")` behandeln, sonst
  ist der Vergleich mit NaN mehrdeutig.
- **Caches mit gerundeten Schlüsseln** (z. B. Temperatur auf 0,1 K) machen
  Ergebnisse abhängig von der Rechenreihenfolge. Das muss erkannt und
  dokumentiert werden.
- **Vermeintliche Fehler zuerst prüfen:** Zwei von drei vermuteten Fehlern
  waren gegenstandslos, einmal toter Code und einmal keine doppelte Anwendung.
- **PDF-Build:**
  - Inline-`$` maskieren.
  - Keine doppelte Kapitelnummerierung.
  - Vor Listen eine Leerzeile setzen.
  - In Regex `[ \t]*` statt `\s*` verwenden.
