"""Baut das PDF-Handbuch aus den Markdown-Kapiteln.

Aufruf (aus dem Projektordner):
    python docs/build_pdf.py        deutsch:  docs/*.md    -> docs/Handbuch_Videoauswertung.pdf
    python docs/build_pdf.py en     englisch: docs/en/*.md -> docs/Handbuch_Videoauswertung_en.pdf

Voraussetzungen: pypandoc_binary (docs/requirements.txt) und XeLaTeX.
"""
import datetime
import pathlib
import re
import subprocess
import sys

import pypandoc

DOCS = pathlib.Path(__file__).resolve().parent
PROJEKT = DOCS.parent
KAPITEL = ['01_installation', '02_messdaten', '03_konfiguration', '04_auswertung', '05_plots',
           '06_gui', '07_methodik', '08_grenzen', '09_erweitern']

SPRACHEN = {
    'de': dict(quelle=DOCS, ziel=DOCS / 'Handbuch_Videoauswertung.pdf', lang='de-DE',
               titel='Videoauswertung Taylor-Flow', untertitel='Handbuch', datum='%d.%m.%Y', stand='Stand'),
    'en': dict(quelle=DOCS / 'en', ziel=DOCS / 'Handbuch_Videoauswertung_en.pdf', lang='en-GB',
               titel='Video Analysis of Taylor Flow', untertitel='Manual', datum='%d %B %Y', stand='version'),
}

KOPF = r"""
\usepackage{fvextra}
\DefineVerbatimEnvironment{Highlighting}{Verbatim}{breaklines,breakanywhere,commandchars=\\\{\}}
\fvset{breaklines,breakanywhere}
\usepackage{etoolbox}
\usepackage{array}
\setlength{\extrarowheight}{2pt}
\AtBeginEnvironment{longtable}{\small\renewcommand{\arraystretch}{1.35}}
\setlength{\emergencystretch}{3em}
\frenchspacing
\counterwithout{figure}{chapter}
\let\originalunderscore\_
\renewcommand{\_}{\originalunderscore\allowbreak}
"""

CODE = re.compile(r'(```.*?```|`[^`\n]*`)', re.S)
LINK = re.compile(r'(?<!!)\[([^\]]+)\]\((?!https?:)[^)]+\)')   # keine Bilder
LISTE = re.compile(r'([^\n])\n([ \t]*(?:[-*]|\d+\.)[ \t]+)')
KOMMENTAR = re.compile(r'<!--.*?-->', re.S)
BILD = re.compile(r'(!\[[^\]]*\]\()(?:\.\./)?(bilder/[^)]+)\)')   # auch ../bilder aus docs/en


def git_stand():
    try:
        return subprocess.run(['git', '-C', str(PROJEKT), 'rev-parse', '--short', 'HEAD'],
                              capture_output=True, text=True, check=True).stdout.strip()
    except (OSError, subprocess.CalledProcessError):
        return 'unbekannt'


def spaltenbreiten(text):
    """Trennzeilen von Pipe-Tabellen an den Zellinhalt anpassen.

    Pandoc-Markdown nimmt die relative Spaltenbreite aus der Anzahl der
    Striche in der Trennzeile; |---|---| ergäbe gleich breite Spalten.
    Jede Spalte ist mindestens so breit wie ihr längstes nicht trennbares
    Wort, lange Textspalten werden begrenzt.
    """
    zeilen = text.split('\n')
    i = 0
    while i < len(zeilen) - 1:
        if zeilen[i].startswith('|') and re.fullmatch(r'\|(\s*:?-+:?\s*\|)+\s*', zeilen[i + 1]):
            j = i + 2
            while j < len(zeilen) and zeilen[j].startswith('|'):
                j += 1
            zellen = [[z.strip() for z in zeile.strip().strip('|').split('|')]
                      for k, zeile in enumerate(zeilen[i:j]) if k != 1]
            n = len(zellen[0])

            def wort(z):   # längstes nicht trennbares Stück (Code bricht nur an _ um)
                return max((len(w) for w in re.split(r'[\s_]+', z.replace('`', ''))), default=0)

            breite = []
            for s in range(n):
                spalte = [z[s] if s < len(z) else '' for z in zellen]
                breite.append(max(8, max(wort(z) for z in spalte) + 3, min(30, max(len(z) for z in spalte))))
            zeilen[i + 1] = '|' + '|'.join('-' * b for b in breite) + '|'
            i = j
        else:
            i += 1
    return '\n'.join(zeilen)


def bereinige(text):
    """Markdown so anpassen, dass Pandoc/XeLaTeX es sauber setzt.

    Nur außerhalb von Code: Links auf andere Kapitel auf ihren Text kürzen,
    Inline-$ maskieren, Leerzeile vor Listen einfügen (sonst hängt Pandoc
    die Liste an den Absatz), HTML-Kommentare entfernen.
    """
    code = []

    def merke(treffer):
        code.append(treffer.group(0))
        return f'\x00{len(code) - 1}\x00'

    t = CODE.sub(merke, text)
    t = LINK.sub(r'\1', t)
    t = t.replace('$', '\\$')
    t = LISTE.sub(r'\1\n\n\2', t)
    t = KOMMENTAR.sub('', t)
    # XeLaTeX läuft in einem temporären Ordner: Bildpfade absolut machen
    t = BILD.sub(lambda m: m.group(1) + (DOCS / m.group(2)).as_posix() + ')', t)
    t = re.sub('\x00(\\d+)\x00', lambda m: code[int(m.group(1))], t)
    return spaltenbreiten(t)


def main(sprache='de'):
    s = SPRACHEN[sprache]
    markdown = '\n\n'.join(bereinige((s['quelle'] / f'{name}.md').read_text(encoding='utf-8')) for name in KAPITEL)
    datum = datetime.date.today().strftime(s['datum'])
    kopf = DOCS / '_kopf.tex'
    kopf.write_text(KOPF, encoding='utf-8')
    argumente = [
        '--pdf-engine=xelatex',
        '--toc', '--toc-depth=2',
        '--top-level-division=chapter',
        '-V', 'documentclass=scrreprt',
        '-V', f"lang={s['lang']}",
        '-V', 'mainfont=DejaVu Serif',
        '-V', 'sansfont=DejaVu Sans',
        '-V', 'monofont=DejaVu Sans Mono',
        '-V', 'fontsize=10pt',
        '-V', 'geometry:margin=2.2cm',
        '-V', 'colorlinks=true',
        '-M', f"title={s['titel']}",
        '-M', f"subtitle={s['untertitel']}",
        '-M', f"date={datum} · {s['stand']} {git_stand()}",
        f'--resource-path={DOCS}',
        '-H', str(kopf),
    ]
    try:
        pypandoc.convert_text(markdown, 'pdf', format='markdown-yaml_metadata_block-fancy_lists',
                              outputfile=str(s['ziel']), extra_args=argumente)
    finally:
        kopf.unlink(missing_ok=True)
    print(f"PDF geschrieben: {s['ziel']}")


if __name__ == '__main__':
    main(sys.argv[1] if len(sys.argv) > 1 else 'de')
