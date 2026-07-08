%% Hauptskript: Gekoppelte Volumen- und Geschwindigkeitsmessung (Einzelvideo)
clc; close all; clear;

% Pfadkonfiguration: src/-Unterordner für die neue Projektstruktur einbinden
scriptDir = fileparts(mfilename('fullpath'));
projectRoot = fileparts(scriptDir);
addpath(fullfile(projectRoot, 'src', 'core'));
addpath(fullfile(projectRoot, 'src', 'io'));
addpath(fullfile(projectRoot, 'src', 'utils'));
addpath(fullfile(projectRoot, 'src', 'config'));

%% 1. Parameter & Konfiguration laden
% Lade zentrale Konfiguration
config = defaultConfig(projectRoot);
config = validateConfig(config);

% --- TEMPORÄRER ADAPTER ---
% Da die Kernfunktionen (detect_Bubbles, etc.) aktuell noch einen flachen 
% 'params'-Struct erwarten, mappen wir die Werte hier temporär um.
% In einer späteren Phase werden die Kernfunktionen auf den config-Struct umgestellt.
params.videoFile             = config.paths.videoFile;
params.calibFile             = config.paths.calibFile;
params.fps                   = config.video.fps;
params.showCalibrationImage  = config.ui.showCalibrationImage;
params.showVisuals           = config.ui.showVisuals;
params.visualizeEveryNFrames = config.ui.visualizeEveryNFrames;
params.dimOffsetY            = config.ui.dimOffsetY;
params.minPixel              = config.detection.minPixel;
params.minArea               = config.detection.minArea;
params.borderMargin          = config.detection.borderMargin;
params.maxJumpDist_px        = config.tracking.maxJumpDist_px;
params.minFramesTracked      = config.tracking.minFramesTracked;
params.kanalStart_mm         = config.physics.kanalStart_mm;
params.binSize_mm            = config.physics.binSize_mm;
params.closeWidth            = config.detection.closeWidth;
params.closeHeight           = config.detection.closeHeight;
params.sens                  = config.detection.sens;
params.showBinarySteps       = config.ui.showBinarySteps;
params.showVelocityTracking  = config.ui.showVelocityTracking;
params.exportImages          = config.ui.exportImages;
params.exportFrame           = config.ui.exportFrame;

%% 2. Auswertungs-Pipeline starten
fprintf('Starte Einzelvideo-Auswertung...\n');

[resultsTable, statsTable, mean_UC_mm, L_ein_mm] = runAnalysisPipeline(...
    params.videoFile, params.calibFile, config, params);

%% 3. Visualisierung & Speichern der Ergebnisse
if config.ui.showVisuals
    fprintf('--- Unit Cell (UC) Auswertung ---\n');
    fprintf('Mittelwert der Unit Cell Laenge (L_uc): %.3f mm\n\n', mean_UC_mm);
    if ~isnan(L_ein_mm)
        fprintf('Berechnete hydrodynamische Einlauflänge: %.2f mm\n', L_ein_mm);
    end
end

visualize_Results(resultsTable, statsTable);

if ~isempty(statsTable)
    outputFile = fullfile(projectRoot, 'output', 'Statistik_Ergebnisse_Kanallaenge.csv');
    writetable(statsTable, outputFile);
    fprintf('Ergebnisse als "%s" gespeichert.\n', outputFile);
end
