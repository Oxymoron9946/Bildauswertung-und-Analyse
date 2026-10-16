function dateien = auswerten_Batch(cfg, basis, rueckmeldung)
% AUSWERTEN_BATCH Wertet alle Messvideos unter einem Ordner parallel aus.
%
% Je Messvideo (cfg.video.dateimuster, außerhalb der Kalibrierordner)
% werte_Messvideo: Laborbuch, Kalibrierung, Auswertung je Wert in
% cfg.detektion.sens. Fehlt etwas, wird das Video mit Warnung übersprungen.
% Ergebnis: eine CSV je Setup in cfg.pfade.ausgabe, bei cfg.plots.batch
% zusätzlich Verlaufsplots je Einstellung (Unterordner plots), dazu
% lauf_config_<Zeit>.json mit allen Einstellungen des Laufs.
%
% Parameter
% ---------
% cfg : struct aus config()
% basis : Messordner (absolut oder relativ zu cfg.pfade.messdaten)
% rueckmeldung : optional, struct mit Funktionen (alle optional):
%     fortschritt(fertig, gesamt)   nach jedem Video (im Client)
%     abbruch() -> logical          entscheidet nach einem Abbruchfehler,
%                                   ob es ein gewollter Abbruch war
%
% Rückgabe
% --------
% dateien : cellstr der geschriebenen CSV-Dateien ({} bei Abbruch)

    if nargin < 3 || isempty(rueckmeldung)
        rueckmeldung = struct();
    end
    videoauswertung.kern.pruefe_Config(cfg);
    basis = absoluter_Pfad(basis, cfg.pfade.messdaten);
    dateien = {};

    labor = videoauswertung.io.lade_Laborbuch(cfg.pfade.laborbuch);
    videos = messvideos(basis, cfg);
    gesamt = numel(videos);
    zaehler = containers.Map({'fertig'}, {0});   % Handle: zählt im Client mit
    ergebnisse = cell(gesamt, 1);
    try
        if parallel_verfuegbar()
            fprintf('Starte parallele Batch-Auswertung für %d Messvideos...\n', gesamt);
            q = parallel.pool.DataQueue;
            afterEach(q, @(~) melde(zaehler, gesamt, rueckmeldung));
            parfor i = 1:gesamt
                ergebnisse{i} = werte_Batchvideo(videos{i}, labor, cfg);
                send(q, 1);
            end
        else
            % Ohne Parallel Computing Toolbox: nacheinander, gleiche Ergebnisse
            fprintf('Starte Batch-Auswertung (nacheinander) für %d Messvideos...\n', gesamt);
            for i = 1:gesamt
                ergebnisse{i} = werte_Batchvideo(videos{i}, labor, cfg);
                melde(zaehler, gesamt, rueckmeldung);
                if isfield(rueckmeldung, 'abbruch') && rueckmeldung.abbruch()
                    error('videoauswertung:abbruch', 'Abbruch durch Benutzer.');
                end
            end
        end
    catch ME
        if isfield(rueckmeldung, 'abbruch') && rueckmeldung.abbruch()
            fprintf('Batch-Auswertung wurde abgebrochen.\n');
            return;
        end
        rethrow(ME);
    end
    fprintf('\nAuswertung aller Videos abgeschlossen!\n');

    dateien = videoauswertung.io.exportiere_Batch(ergebnisse, cfg.pfade.ausgabe);
    videoauswertung.io.schreibe_Laufconfig(cfg, 'batch', basis);
    if cfg.plots.batch
        stil = videoauswertung.plots.PlotStil(cfg);
        for k = 1:numel(dateien)
            videoauswertung.plots.erzeuge_Batchplots(dateien{k}, stil);
        end
    end
end

function ja = parallel_verfuegbar()
    % Parallel Computing Toolbox installiert und lizenziert?
    ja = ~isempty(ver('parallel')) && license('test', 'Distrib_Computing_Toolbox');
end

function melde(zaehler, gesamt, rueckmeldung)
    zaehler('fertig') = zaehler('fertig') + 1;
    if isfield(rueckmeldung, 'fortschritt')
        rueckmeldung.fortschritt(zaehler('fertig'), gesamt);
    else
        fprintf('Fortschritt: %d / %d Videos\n', zaehler('fertig'), gesamt);
    end
end

function tab = werte_Batchvideo(video, labor, cfg)
    % Fehler eines Videos brechen den Batch nicht ab: Warnung, Video überspringen
    try
        tab = videoauswertung.kern.werte_Messvideo(video, labor, cfg);
    catch ME
        warning('ÜBERSPRUNGEN: %s', ME.message);
        tab = table();
    end
end

function videos = messvideos(basis, cfg)
    alle = dir(fullfile(basis, '**', cfg.video.dateimuster));
    if isempty(alle)
        error('videoauswertung:keineVideos', 'Keine passenden .avi Dateien unter %s gefunden!', basis);
    end
    alle = alle(~contains({alle.folder}, erase(cfg.kalibrierung.ordnermuster, '*')));
    videos = fullfile({alle.folder}, {alle.name})';
end

function p = absoluter_Pfad(p, wurzel)
    p = char(p);
    if ~isfolder(p) || ~java.io.File(p).isAbsolute()
        kandidat = fullfile(wurzel, p);
        if isfolder(kandidat)
            p = kandidat;
        end
    end
    if ~isfolder(p)
        error('videoauswertung:ordnerFehlt', 'Messordner nicht gefunden: %s', p);
    end
end
