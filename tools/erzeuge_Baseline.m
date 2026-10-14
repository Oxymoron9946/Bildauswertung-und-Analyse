function erzeuge_Baseline(zielDir, datensaetze, einzelVideos)
% ERZEUGE_BASELINE Friert die Ausgaben des aktuellen Stands als Referenz ein.
%
% Ruft den Batch-Ablauf (runBatchPipeline) je Messordner und den
% Einzelvideo-Ablauf der GUI (start_AnalysisFromGUI, Modus 'single') ohne
% Bedienoberfläche auf und verschiebt die erzeugten CSV-Dateien nach zielDir.
%
% Eingaben:
%   zielDir      - Zielordner, z. B. _archiv/baseline_<commit>
%   datensaetze  - cellstr der Messordner relativ zum Projekt (Batch-Ablauf)
%   einzelVideos - cellstr der Messvideos relativ zum Projekt (GUI-Einzelablauf)
%
% Aufruf (aus dem Projektordner):
%   matlab -batch "addpath tools; erzeuge_Baseline('_archiv/baseline_0cf713b', {'PVC_1500_1150'}, {})"

    projectRoot = fileparts(fileparts(mfilename('fullpath')));
    addpath(fullfile(projectRoot, 'src', 'core'));
    addpath(fullfile(projectRoot, 'src', 'io'));
    addpath(fullfile(projectRoot, 'src', 'utils'));
    addpath(fullfile(projectRoot, 'src', 'config'));

    if ~isfolder(zielDir)
        mkdir(zielDir);
    end
    outputDir = fullfile(projectRoot, 'output');
    if isfolder(outputDir) && ~isempty(setdiff({dir(outputDir).name}, {'.', '..'}))
        error('output/ ist nicht leer. Bitte vorher nach _archiv/ verschieben.');
    end

    diary(fullfile(zielDir, sprintf('protokoll_%s.txt', datestr(now, 'yyyymmdd_HHMMSS')))); %#ok<TNOW1,DATST>
    cleanupDiary = onCleanup(@() diary('off'));
    [~, commit] = system('git rev-parse HEAD');
    fprintf('Baseline für Commit %s, MATLAB %s\n', strtrim(commit), version);

    config = defaultConfig(projectRoot);
    config = validateConfig(config);
    config.ui.showVisuals          = false;
    config.ui.showCalibrationImage = false;
    config.ui.exportImages         = false;

    % --- Batch-Ablauf je Messordner ---
    for k = 1:numel(datensaetze)
        ds = datensaetze{k};
        fprintf('\n===== Batch: %s =====\n', ds);
        t0 = tic;
        runBatchPipeline(config, fullfile(projectRoot, ds));
        fprintf('Dauer %s: %.1f min\n', ds, toc(t0) / 60);
        verschiebe(outputDir, fullfile(zielDir, 'batch', ds));
    end

    % --- GUI-Einzelablauf mit den GUI-Startwerten (Sens. 0,85) ---
    for k = 1:numel(einzelVideos)
        vid = fullfile(projectRoot, einzelVideos{k});
        fprintf('\n===== GUI-Einzel: %s =====\n', einzelVideos{k});
        cfg = config;
        cfg.detection.sensArray = 0.85;
        t0 = tic;
        start_AnalysisFromGUI('single', cfg, vid);
        fprintf('Dauer: %.1f min\n', toc(t0) / 60);
    end
    if ~isempty(einzelVideos)
        verschiebe(outputDir, fullfile(zielDir, 'gui_einzel'));
    end
end

function verschiebe(outputDir, ziel)
    if ~isfolder(outputDir)
        warning('Keine Ausgabe erzeugt (%s fehlt).', outputDir);
        return;
    end
    if ~isfolder(fileparts(ziel))
        mkdir(fileparts(ziel));
    end
    movefile(outputDir, ziel);
end
