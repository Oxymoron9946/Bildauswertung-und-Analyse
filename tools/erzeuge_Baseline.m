function erzeuge_Baseline(zielDir, datensaetze, einzelVideos, messdaten)
% ERZEUGE_BASELINE Wertet alle Messordner aus und legt die Ergebnisse ab.
%
% Dient dem Vollvergleich mit der Baseline des Ausgangsstands
% (_archiv/baseline_0cf713b, erzeugt mit dem Stand archiv/vor-uebergabe).
% Ablage: <zielDir>/batch/<Messordner>/... und <zielDir>/gui_einzel/...
%
% Parameter
% ---------
% zielDir : Zielordner
% datensaetze : cellstr der Messordner relativ zu cfg.pfade.messdaten (Batch)
% einzelVideos : cellstr der Messvideos relativ zu cfg.pfade.messdaten
%                (Einzelauswertung mit cfg.detektion.sens)
% messdaten : optional, Ordner der Messreihen (Standard: cfg.pfade.messdaten),
%             z. B. für Läufe aus einem git-Worktree ohne Videos
%
% Aufruf (aus dem Projektordner):
%   matlab -batch "addpath tools; erzeuge_Baseline('_archiv/neu', {'PVC_1500_1150'}, {})"

    projekt = fileparts(fileparts(mfilename('fullpath')));
    addpath(projekt);
    if ~isfolder(zielDir)
        mkdir(zielDir);
    end
    diary(fullfile(zielDir, sprintf('protokoll_%s.txt', char(datetime('now', 'Format', 'yyyyMMdd_HHmmss')))));
    aufraeumen = onCleanup(@() diary('off'));
    [~, commit] = system(sprintf('git -C "%s" rev-parse HEAD', projekt));
    fprintf('Baseline für Commit %s, MATLAB %s\n', strtrim(commit), version);

    cfg = config();
    if nargin >= 4 && ~isempty(messdaten)
        cfg.pfade.messdaten = messdaten;
    end
    for k = 1:numel(datensaetze)
        fprintf('\n===== Batch: %s =====\n', datensaetze{k});
        lauf = cfg;
        lauf.pfade.ausgabe = fullfile(zielDir, 'batch', datensaetze{k});
        t0 = tic;
        videoauswertung.kern.auswerten_Batch(lauf, datensaetze{k});
        fprintf('Dauer %s: %.1f min\n', datensaetze{k}, toc(t0) / 60);
    end

    for k = 1:numel(einzelVideos)
        fprintf('\n===== Einzel: %s =====\n', einzelVideos{k});
        lauf = cfg;
        lauf.pfade.ausgabe = fullfile(zielDir, 'gui_einzel');
        t0 = tic;
        videoauswertung.kern.auswerten_Einzel(lauf, fullfile(cfg.pfade.messdaten, einzelVideos{k}));
        fprintf('Dauer: %.1f min\n', toc(t0) / 60);
    end
end
