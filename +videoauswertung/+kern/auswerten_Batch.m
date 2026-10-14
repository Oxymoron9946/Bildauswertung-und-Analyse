function dateien = auswerten_Batch(cfg, basis, rueckmeldung)
% AUSWERTEN_BATCH Wertet alle Messvideos unter einem Ordner parallel aus.
%
% 1. Kalibrierung je Gruppe "Pos_<n>_Kal_<k>" aus den Kalibrierordnern
%    (cfg.kalibrierung.ordnermuster).
% 2. Je Messvideo (cfg.video.dateimuster, außerhalb der Kalibrierordner):
%    Laborbuchzeile über den Messlauf, Pflichtfelder prüfen, auswerten.
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
    [kalibDatei, ~] = kalibrierungen(basis, cfg);
    videos = messvideos(basis, cfg);
    gesamt = numel(videos);
    fprintf('Starte parallele Batch-Auswertung für %d Messvideos...\n', gesamt);

    q = parallel.pool.DataQueue;
    zaehler = containers.Map({'fertig'}, {0});   % Handle: zählt im Client mit
    afterEach(q, @(~) melde(zaehler, gesamt, rueckmeldung));

    ergebnisse = cell(gesamt, 1);
    try
        parfor i = 1:gesamt
            ergebnisse{i} = werte_Batchvideo(videos{i}, kalibDatei, labor, cfg);
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

function tab = werte_Batchvideo(video, kalibDatei, labor, cfg)
    tab = table();
    m = videoauswertung.kern.lies_Messlauf(video);
    if isempty(m.gruppe)
        warning('ÜBERSPRUNGEN: Video hat kein "Pos_X_Kal_Y" im Pfad: %s', video);
        return;
    end

    zeile = find(strcmp(string(labor.Dateiname), m.name));
    if isempty(zeile)
        warning('ÜBERSPRUNGEN: Ordner "%s" wurde im Laborbuch (Spalte "Dateiname") nicht gefunden!', m.name);
        return;
    end
    zeile = zeile(1);
    p_Pa      = labor.Umgebungsdruck(zeile);
    temp_C    = labor.Umgebungstemperatur(zeile);
    co2       = labor.("CO2-Anteil")(zeile);
    reaktor_L = labor.Kanallaenge(zeile);
    offset_mm = labor.Offset(zeile);
    pflicht = {p_Pa, 'Umgebungsdruck'; temp_C, 'Umgebungstemperatur'; co2, 'CO2-Anteil'; ...
               reaktor_L, 'Kanallaenge'; offset_mm, 'Offset'};
    for k = 1:size(pflicht, 1)
        if ismissing(pflicht{k, 1}) || isnan(pflicht{k, 1})
            warning('ÜBERSPRUNGEN: Im Laborbuch fehlt "%s" für den Ordner "%s"!', pflicht{k, 2}, m.name);
            return;
        end
    end

    try
        if ~isKey(kalibDatei, m.gruppe)
            error('Schlüssel "%s" existiert nicht in der Kalibrier-Map!', m.gruppe);
        end
        erg = videoauswertung.kern.werte_Video_aus(video, kalibDatei(m.gruppe), offset_mm, cfg);
        bins = erg.bins;
        n = height(bins);
        if n > 0
            meta = table(repmat(m.gas, n, 1), repmat(m.liq, n, 1), repmat(m.pos, n, 1), ...
                repmat(m.material, n, 1), repmat(m.form, n, 1), ...
                repmat(str2double(m.kanal), n, 1), repmat(str2double(m.nadel), n, 1), ...
                repmat(reaktor_L, n, 1), repmat(p_Pa, n, 1), repmat(temp_C, n, 1), ...
                repmat(co2, n, 1), repmat(m.messart, n, 1), repmat(cfg.detektion.sens, n, 1), ...
                'VariableNames', {'GasVelocity', 'LiquidVelocity', 'CameraPosition', ...
                'Material', 'Geometrie', 'Kanal_um', 'Nadel_um', 'Reaktor_cm', ...
                'Druck_Pa_Auslass', 'Temperatur_C', 'CO2_Anteil', 'Messart', 'UsedSensitivity'});
            bins = [meta, bins];
            bins.Properties.RowNames = {};
        end
        tab = bins;
    catch ME
        warning('Fehler bei Video %s: %s', m.name, ME.message);
    end
end

function [kalibDatei, px2mm] = kalibrierungen(basis, cfg)
    % Je Gruppe gilt das zuletzt gefundene erfolgreich kalibrierte Video
    % (Befund F01: gleiche Gruppe in mehreren Teilordnern wird überschrieben).
    kalibDatei = containers.Map('KeyType', 'char', 'ValueType', 'char');
    px2mm = containers.Map('KeyType', 'char', 'ValueType', 'double');
    fprintf('\n--- Lese Kalibrierungen ein ---\n');
    liste = dir(fullfile(basis, '**', cfg.kalibrierung.ordnermuster, '*.avi'));
    for c = 1:numel(liste)
        tok = regexp(liste(c).folder, '(Pos_\d+_Kal_\d+)', 'tokens');
        if isempty(tok)
            continue;
        end
        gruppe = tok{1}{1};
        datei = fullfile(liste(c).folder, liste(c).name);
        frame = readFrame(VideoReader(datei));
        if ndims(frame) == 3
            frame = rgb2gray(frame);
        end
        [s, ok] = videoauswertung.kern.kalibriere_Massstab(frame, cfg);
        if ok
            px2mm(gruppe) = s;
            kalibDatei(gruppe) = datei;
            fprintf('Gruppe %s: %.5f mm/px\n', gruppe, s);
        end
    end
    fprintf('--------------------------------\n\n');
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
