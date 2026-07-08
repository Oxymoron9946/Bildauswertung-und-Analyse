%% Parallele Batch-Auswertung (Skript-Launcher)
clc; close all; clear;
% Pfadkonfiguration
scriptDir = fileparts(mfilename('fullpath'));
projectRoot = fileparts(scriptDir);
addpath(fullfile(projectRoot, 'src', 'core'));
addpath(fullfile(projectRoot, 'src', 'io'));
addpath(fullfile(projectRoot, 'src', 'utils'));
addpath(fullfile(projectRoot, 'src', 'config'));
% 1. Konfiguration laden
config = defaultConfig(projectRoot);
config = validateConfig(config);
% 2. Ordner auswählen
baseDir = uigetdir('', 'Bitte den Hauptordner (z.B. "Glaskanal") auswählen');
if baseDir == 0
    fprintf('Abbruch durch Benutzer.\n');
    return;
end
% 3. Batch-Pipeline starten
fprintf('Starte Batch-Auswertung...\n');
runBatchPipeline(config, baseDir);
fprintf('Fertig.\n');