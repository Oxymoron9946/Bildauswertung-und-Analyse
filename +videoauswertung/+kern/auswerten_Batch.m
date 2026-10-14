function dateien = auswerten_Batch(cfg, basis, rueckmeldung)
% AUSWERTEN_BATCH Wertet alle Messvideos unter einem Ordner parallel aus.
%
% 1. Kalibriervideo je Messvideo aus dem eigenen Gruppenordner
%    "Pos_<n>_Kal_<k>" (finde_Kalibrierung).
% 2. Je Messvideo (cfg.video.dateimuster, außerhalb der Kalibrierordner):
%    Laborbuchzeile über den Messlauf, Pflichtfelder prüfen, auswerten,
%    und zwar je Wert in cfg.detektion.sens (Spalte UsedSensitivity).
%    Fehlt etwas, wird das Video mit Warnung übersprungen.
% 3. Ergebnisse je Messart als CSV nach cfg.pfade.ausgabe; bei
%    cfg.plots.batch zusätzlich Verlaufsplots je Einstellung (Unterordner plots).
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
    fprintf('Starte parallele Batch-Auswertung für %d Messvideos...\n', gesamt);

    q = parallel.pool.DataQueue;
    zaehler = containers.Map({'fertig'}, {0});   % Handle: zählt im Client mit
    afterEach(q, @(~) melde(zaehler, gesamt, rueckmeldung));

    ergebnisse = cell(gesamt, 1);
    try
        parfor i = 1:gesamt
            ergebnisse{i} = werte_Batchvideo(videos{i}, labor, cfg);
            send(q, 1);
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
    if cfg.plots.batch
        stil = videoauswertung.plots.PlotStil(cfg);
        for k = 1:numel(dateien)
            videoauswertung.plots.erzeuge_Batchplots(dateien{k}, stil);
        end
    end
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
    tab = table();
    m = videoauswertung.kern.lies_Messlauf(video);
    if isempty(m.gruppe)
        warning('ÜBERSPRUNGEN: Video hat kein "Pos_X_Kal_Y" im Pfad: %s', video);
        return;
    end

    try
        z = videoauswertung.kern.lies_Laborbuchzeile(labor, m);
    catch ME
        warning('ÜBERSPRUNGEN: %s', ME.message);
        return;
    end
    p_Pa = z.p_Pa; temp_C = z.temp_C; co2 = z.co2; reaktor_L = z.reaktor_cm; offset_mm = z.offset_mm;

    if m.messart == "Druckkalibrierung" && ~isnan(cfg.laborbuch.co2_anteil_druck)
        co2 = cfg.laborbuch.co2_anteil_druck;   % Laborbuch-Korrektur, siehe config.m
    end

    try
        kalib = videoauswertung.kern.finde_Kalibrierung(video, cfg);
        teile = cell(numel(cfg.detektion.sens), 1);
        for k = 1:numel(cfg.detektion.sens)
            lauf = cfg;
            lauf.detektion.sens = cfg.detektion.sens(k);
            erg = videoauswertung.kern.werte_Video_aus(video, kalib, offset_mm, lauf);
            teile{k} = mit_Metadaten(erg.bins, m, reaktor_L, p_Pa, temp_C, co2, lauf.detektion.sens);
        end
        teile = teile(~cellfun(@isempty, teile));
        if ~isempty(teile)
            tab = vertcat(teile{:});
        end
    catch ME
        warning('Fehler bei Video %s: %s', m.name, ME.message);
    end
end

function bins = mit_Metadaten(bins, m, reaktor_L, p_Pa, temp_C, co2, sens)
    n = height(bins);
    if n > 0
        meta = table(repmat(m.gas, n, 1), repmat(m.liq, n, 1), repmat(m.pos, n, 1), repmat(m.aufnahme, n, 1), ...
            repmat(m.material, n, 1), repmat(m.form, n, 1), ...
            repmat(str2double(m.kanal), n, 1), repmat(str2double(m.nadel), n, 1), ...
            repmat(reaktor_L, n, 1), repmat(p_Pa, n, 1), repmat(temp_C, n, 1), ...
            repmat(co2, n, 1), repmat(m.messart, n, 1), repmat(sens, n, 1), ...
            'VariableNames', {'GasVelocity', 'LiquidVelocity', 'CameraPosition', 'Aufnahme', ...
            'Material', 'Geometrie', 'Kanal_um', 'Nadel_um', 'Reaktor_cm', ...
            'Druck_Pa_Auslass', 'Temperatur_C', 'CO2_Anteil', 'Messart', 'UsedSensitivity'});
        bins = [meta, bins];
        bins.Properties.RowNames = {};
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
