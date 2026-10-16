%% Batch-Auswertung aller Messvideos unter einem Messordner
% Ergebnisse: cfg.pfade.ausgabe (Standard: output/), eine CSV je Messart.
% Einstellungen: config.m; hier nur laufbezogene Änderungen.

addpath(fileparts(mfilename('fullpath')));   % Projektordner (Paket videoauswertung, config.m)
cfg = config();

messordner = 'PVC_1500_1150';   % relativ zu cfg.pfade.messdaten oder absolut

videoauswertung.kern.auswerten_Batch(cfg, messordner);
