function [tab, rohdaten] = werte_Messvideo(video, labor, cfg, rueckmeldung)
% WERTE_MESSVIDEO Ein Messvideo samt Metadaten auswerten (Batch und Einzel).
%
% Messlauf und Aufnahme aus dem Pfad, Pflichtangaben aus dem Laborbuch,
% Kalibriervideo aus dem Gruppenordner; dann je Wert in cfg.detektion.sens
% eine Auswertung (werte_Video_aus). Fehlt etwas, bricht die Funktion mit
% einer Meldung ab; der Batch macht daraus eine Warnung und überspringt das
% Video.
%
% Parameter
% ---------
% video : Pfad zum Messvideo
% labor : table aus lade_Laborbuch
% cfg : struct aus config()
% rueckmeldung : optional, siehe werte_Video_aus
%
% Rückgabe
% --------
% tab : Bins mit Metadaten, eine Zeile je Bin und Sensitivität
%       (Spalten siehe docs/04_auswertung.md); leer, wenn kein Bin gültig ist
% rohdaten : Messpunkte des letzten Durchlaufs (für Plots)

    if nargin < 4
        rueckmeldung = struct();
    end
    m = videoauswertung.kern.lies_Messlauf(video);
    kalib = videoauswertung.kern.finde_Kalibrierung(video, cfg);
    z = videoauswertung.kern.lies_Laborbuchzeile(labor, m);
    if m.messart == "Druckkalibrierung" && ~isnan(cfg.laborbuch.co2_anteil_druck)
        z.co2 = cfg.laborbuch.co2_anteil_druck;   % Laborbuch-Korrektur, siehe config.m
    end

    teile = cell(numel(cfg.detektion.sens), 1);
    rohdaten = table();
    for k = 1:numel(cfg.detektion.sens)
        lauf = cfg;
        lauf.detektion.sens = cfg.detektion.sens(k);
        erg = videoauswertung.kern.werte_Video_aus(video, kalib, z.offset_mm, lauf, rueckmeldung);
        if ~isempty(erg.rohdaten)
            rohdaten = erg.rohdaten;
        end
        teile{k} = mit_Metadaten(erg.bins, m, z, lauf.detektion.sens);
        if erg.abgebrochen
            break;
        end
    end
    teile = teile(~cellfun(@isempty, teile));
    if isempty(teile)
        tab = table();
    else
        tab = vertcat(teile{:});
    end
end

function bins = mit_Metadaten(bins, m, z, sens)
    n = height(bins);
    if n == 0
        return;
    end
    meta = table(repmat(m.gas, n, 1), repmat(m.liq, n, 1), repmat(m.pos, n, 1), repmat(m.aufnahme, n, 1), ...
        repmat(m.material, n, 1), repmat(m.form, n, 1), ...
        repmat(str2double(m.kanal), n, 1), repmat(str2double(m.nadel), n, 1), ...
        repmat(z.reaktor_cm, n, 1), repmat(z.p_Pa, n, 1), repmat(z.temp_C, n, 1), ...
        repmat(z.co2, n, 1), repmat(m.messart, n, 1), repmat(sens, n, 1), ...
        'VariableNames', {'GasVelocity', 'LiquidVelocity', 'CameraPosition', 'Aufnahme', ...
        'Material', 'Geometrie', 'Kanal_um', 'Nadel_um', 'Reaktor_cm', ...
        'Druck_Pa_Auslass', 'Temperatur_C', 'CO2_Anteil', 'Messart', 'UsedSensitivity'});
    % numel_* je Größe ist immer gleich GroupCount (Gate C10)
    bins = removevars(bins, bins.Properties.VariableNames(startsWith(bins.Properties.VariableNames, 'numel_')));
    bins = [meta, bins];
    bins.Properties.RowNames = {};
end
