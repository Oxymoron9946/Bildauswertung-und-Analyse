function T = fuehre_Regressionslauf(art, ziel, ausgabe)
% FUEHRE_REGRESSIONSLAUF Wertet ein Regressionsziel aus und liest das Ergebnis.
%
% Parameter
% ---------
% art : 'batch' (Messordner) oder 'einzel' (Aufnahmeordner mit einem Video)
% ziel : absoluter Pfad
% ausgabe : leerer Ordner für die erzeugten CSV-Dateien
%
% Rückgabe
% --------
% T : Ergebnistabelle, gelesen aus der erzeugten CSV (alle Spalten als Text)
%
% Stand: alter Code (0cf713b). Die Funktionen schreiben fest nach
% <projekt>/output; ein vorhandener Ordner wird für die Dauer des Laufs
% beiseitegelegt und danach wiederhergestellt.

    cfg = config();
    projekt = cfg.pfade.projekt;
    addpath(fullfile(projekt, 'src', 'core'), fullfile(projekt, 'src', 'io'), ...
        fullfile(projekt, 'src', 'utils'), fullfile(projekt, 'src', 'config'));

    alt = defaultConfig(projekt);
    alt.ui.showVisuals          = false;
    alt.ui.showCalibrationImage = false;
    alt.ui.exportImages         = false;

    outDir = fullfile(projekt, 'output');
    parkplatz = '';
    if isfolder(outDir)
        parkplatz = [outDir '_vor_regressionstest_' char(java.util.UUID.randomUUID)];
        movefile(outDir, parkplatz);
    end
    aufraeumen = onCleanup(@() stelle_wieder_her(outDir, parkplatz, ausgabe));

    switch art
        case 'batch'
            runBatchPipeline(alt, ziel);
        case 'einzel'
            video = dir(fullfile(ziel, cfg.video.dateimuster));
            assert(isscalar(video), 'Im Aufnahmeordner muss genau ein Video liegen: %s', ziel);
            alt.detection.sensArray = cfg.gui.sens_start;
            start_AnalysisFromGUI('single', alt, fullfile(video.folder, video.name));
        otherwise
            error('Unbekannte Art: %s', art);
    end

    csv = dir(fullfile(outDir, '**', '*.csv'));
    assert(isscalar(csv), 'Erwartet genau eine Ergebnis-CSV, gefunden: %d', numel(csv));
    datei = fullfile(csv.folder, csv.name);
    opts = detectImportOptions(datei, 'TextType', 'string', 'VariableNamingRule', 'preserve');
    T = readtable(datei, setvartype(opts, 'string'));
end

function stelle_wieder_her(outDir, parkplatz, ausgabe)
    if isfolder(outDir)
        if ~isfolder(ausgabe), mkdir(ausgabe); end
        movefile(fullfile(outDir, '*'), ausgabe);
        rmdir(outDir, 's');
    end
    if ~isempty(parkplatz)
        movefile(parkplatz, outDir);
    end
end
