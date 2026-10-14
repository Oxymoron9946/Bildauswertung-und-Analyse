%% Auswertung eines einzelnen Messvideos mit Live-Ansicht und Ergebnisplots
% Kalibriervideo und Offset werden aus Ordnerstruktur und Laborbuch bestimmt.
% Einstellungen: config.m; hier nur laufbezogene Änderungen.

addpath(fileparts(mfilename('fullpath')));   % Projektordner (Paket videoauswertung, config.m)
cfg = config();
cfg.anzeige.live = true;

video = fullfile(cfg.pfade.messdaten, 'PTFE_1000_600', 'Auswertung_20_CO2', 'Pos_1_Kal_1', ...
    '0.198_0.111_Pos_1_R_1000_PTFE_600', '200fps_001', 'XSM-3520 Camera 0330_.avi');

fig = figure('Name', 'Live-Ansicht', 'Position', [100 200 1000 300]);
rueck.live = @(I, seeds, det, px2mm, frame) videoauswertung.plots.zeige_Live(gca(fig), I, seeds, det, px2mm, frame);
[datei, rohdaten, bins] = videoauswertung.kern.auswerten_Einzel(cfg, video, [], rueck);
videoauswertung.plots.zeige_Ergebnisse(rohdaten, bins);
