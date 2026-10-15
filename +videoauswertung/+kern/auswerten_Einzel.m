function [datei, rohdaten, tabelle] = auswerten_Einzel(cfg, video, sensListe, rueckmeldung)
% AUSWERTEN_EINZEL Wertet ein Messvideo aus, optional mit Live-Ansicht.
%
% Gleiche Auswertung und gleiches Ausgabeformat wie der Batch
% (werte_Messvideo), aber für ein Video und mit Rückmeldungen für die
% Anzeige. Fehlt etwas (Kalibrierung, Laborbuch), bricht die Funktion mit
% einer Meldung ab.
%
% Parameter
% ---------
% cfg : struct aus config()
% video : Pfad zum Messvideo
% sensListe : optional, Sensitivitäten [0..1]; leer = cfg.detektion.sens
% rueckmeldung : optional, siehe werte_Video_aus
%
% Rückgabe
% --------
% datei : geschriebene CSV ('' wenn kein Bin gültig ist)
% rohdaten : Messpunkte des letzten Durchlaufs (für Plots)
% tabelle : Bins mit Metadaten wie im Batch

    if nargin >= 3 && ~isempty(sensListe)
        cfg.detektion.sens = sensListe;
    end
    if nargin < 4
        rueckmeldung = struct();
    end
    videoauswertung.kern.pruefe_Config(cfg);
    video = char(video);

    labor = videoauswertung.io.lade_Laborbuch(cfg.pfade.laborbuch);
    [tabelle, rohdaten] = videoauswertung.kern.werte_Messvideo(video, labor, cfg, rueckmeldung);

    datei = '';
    if isempty(tabelle)
        fprintf('Keine gültigen Bins für %s.\n', video);
        return;
    end
    datei = videoauswertung.io.exportiere_Einzel(tabelle, videoauswertung.kern.lies_Messlauf(video), ...
        cfg.pfade.ausgabe);
    videoauswertung.io.schreibe_Laufconfig(cfg, 'einzel', video);
end
