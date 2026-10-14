function [datei, rohdaten, tabelle] = auswerten_Einzel(cfg, video, sensListe, rueckmeldung)
% AUSWERTEN_EINZEL Wertet ein Messvideo für eine oder mehrere Sensitivitäten aus.
%
% Kalibriervideo: finde_Kalibrierung (eigener Gruppenordner).
% Bildrate: aus "<fps>fps" im Videopfad, sonst cfg.video.fps (werte_Video_aus).
% Offset: aus dem Laborbuch; fehlt der Messlauf oder eine Pflichtangabe,
% bricht die Auswertung mit einer Meldung ab (wie im Batch).
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

    labor = videoauswertung.io.lade_Laborbuch(cfg.pfade.laborbuch);
    z = videoauswertung.kern.lies_Laborbuchzeile(labor, m);
    offset_mm = z.offset_mm;
    fprintf('Offset aus Laborbuch für "%s": %.1f mm.\n', m.name, offset_mm);

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

