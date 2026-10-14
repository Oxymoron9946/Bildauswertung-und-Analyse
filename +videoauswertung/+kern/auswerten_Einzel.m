function [datei, rohdaten, tabelle] = auswerten_Einzel(cfg, video, sensListe, rueckmeldung)
% AUSWERTEN_EINZEL Wertet ein Messvideo für eine oder mehrere Sensitivitäten aus.
%
% Kalibriervideo: finde_Kalibrierung (eigener Gruppenordner).
% Bildrate: aus "<fps>fps" im Pfad, sonst cfg.video.fps.
% Offset: aus dem Laborbuch; fehlt der Eintrag, gilt cfg.physik.kanalstart_mm
% (Befund F11: ohne Fehlermeldung).
%
% Parameter
% ---------
% cfg : struct aus config()
% video : Pfad zum Messvideo
% sensListe : Sensitivitäten [0..1]; leer = cfg.detektion.sens
% rueckmeldung : optional, siehe werte_Video_aus
%
% Rückgabe
% --------
% datei : geschriebene CSV ('' wenn keine gültigen Daten)
% rohdaten : Rohdaten des letzten Durchlaufs (für den Rückmeldeplot)
% tabelle : Bins aller Durchläufe mit Spalte UsedSensitivity

    if nargin < 3 || isempty(sensListe)
        sensListe = cfg.detektion.sens;
    end
    if nargin < 4
        rueckmeldung = struct();
    end
    videoauswertung.kern.pruefe_Config(cfg);
    video = char(video);
    m = videoauswertung.kern.lies_Messlauf(video);
    kalib = videoauswertung.kern.finde_Kalibrierung(video, cfg);
    fprintf('Kalibrierdatei: %s\n', kalib);

    fpsTok = regexp(video, '(\d+)fps', 'tokens');
    if ~isempty(fpsTok)
        cfg.video.fps = str2double(fpsTok{end}{1});
    end

    labor = videoauswertung.io.lade_Laborbuch(cfg.pfade.laborbuch);
    zeile = find(strcmp(string(labor.Dateiname), m.name));
    offset_mm = cfg.physik.kanalstart_mm;
    if ~isempty(zeile) && ~ismissing(labor.Offset(zeile(1))) && ~isnan(labor.Offset(zeile(1)))
        offset_mm = labor.Offset(zeile(1));
        fprintf('Offset aus Laborbuch für "%s": %.1f mm.\n', m.name, offset_mm);
    else
        fprintf('Kein Laborbuch-Eintrag für "%s" gefunden – nutze Config-Fallback (Offset = %.1f mm).\n', ...
            m.name, offset_mm);
    end

    teile = cell(numel(sensListe), 1);
    rohdaten = [];
    for k = 1:numel(sensListe)
        fprintf('--- Durchlauf %d/%d (Sensitivität: %.2f) ---\n', k, numel(sensListe), sensListe(k));
        cfg.detektion.sens = sensListe(k);
        erg = videoauswertung.kern.werte_Video_aus(video, kalib, offset_mm, cfg, rueckmeldung);
        if ~isempty(erg.rohdaten)
            rohdaten = erg.rohdaten;
        end
        if ~isempty(erg.bins)
            teile{k} = [table(repmat(sensListe(k), height(erg.bins), 1), ...
                'VariableNames', {'UsedSensitivity'}), erg.bins];
        end
        if erg.abgebrochen
            break;
        end
    end

    datei = '';
    gueltig = ~cellfun(@isempty, teile);
    if ~any(gueltig)
        tabelle = table();
        fprintf('Keine validen Daten zur Speicherung gefunden.\n');
        return;
    end
    tabelle = vertcat(teile{gueltig});
    datei = videoauswertung.io.exportiere_Einzel(tabelle, m, cfg.pfade.ausgabe);
end

