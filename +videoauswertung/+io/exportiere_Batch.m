function dateien = exportiere_Batch(ergebnisse, ausgabe)
% EXPORTIERE_BATCH Schreibt die Batch-Ergebnisse als CSV (Semikolon), eine Datei je Setup.
%
% Setup = Messart, Material, Geometrie, Kanal_um, Reaktor_cm, CO2_Anteil,
% Nadel_um. Der Dateiname nennt genau diese Werte, z. B.
%   Output_MassTransfer/Auswertung_Masse_PTFE_R_1000um_72cm_20molCO2_600um.csv
% (vorher eine Datei je Messart, benannt nach der ersten Zeile, Befund F08).
%
% Parameter
% ---------
% ergebnisse : cell, je Video eine Tabelle (leer = übersprungen)
% ausgabe : Ausgabeordner (cfg.pfade.ausgabe)
%
% Rückgabe
% --------
% dateien : cellstr der geschriebenen Dateien

    dateien = {};
    gueltig = cellfun(@(x) ~isempty(x) && istable(x) && height(x) > 0, ergebnisse);
    if ~any(gueltig)
        fprintf('Keine validen Daten zur Speicherung gefunden.\n');
        return;
    end
    alle = vertcat(ergebnisse{gueltig});

    setup = {'Messart', 'Material', 'Geometrie', 'Kanal_um', 'Reaktor_cm', 'CO2_Anteil', 'Nadel_um'};
    schluessel = strings(height(alle), 1);
    for c = setup
        schluessel = schluessel + "|" + string(alle.(c{1}));   % Text, damit NaN eine Gruppe bildet
    end
    [~, ~, gruppe] = unique(schluessel, 'stable');
    for g = 1:max(gruppe)
        teil = alle(gruppe == g, :);
        if string(teil.Messart(1)) == "Druckkalibrierung"
            ordner = fullfile(ausgabe, 'Output_PressureCalibration');
            praefix = 'Auswertung_Druck';
        else
            ordner = fullfile(ausgabe, 'Output_MassTransfer');
            praefix = 'Auswertung_Masse';
        end
        if ~isfolder(ordner)
            mkdir(ordner);
        end
        name = sprintf('%s_%s_%s_%sum_%scm_%smolCO2_%sum.csv', praefix, teil.Material(1), ...
            teil.Geometrie(1), num2str(teil.Kanal_um(1)), num2str(teil.Reaktor_cm(1)), ...
            num2str(teil.CO2_Anteil(1) * 100), num2str(teil.Nadel_um(1)));
        datei = fullfile(ordner, name);
        writetable(teil, datei, 'Delimiter', ';');
        fprintf('ERFOLG: %d Zeilen gespeichert in %s\n', height(teil), datei);
        dateien{end+1} = datei; %#ok<AGROW>
    end
end
