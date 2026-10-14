function dateien = exportiere_Batch(ergebnisse, ausgabe)
% EXPORTIERE_BATCH Schreibt die Batch-Ergebnisse je Messart als CSV (Semikolon).
%
% Ausgabeordner: <ausgabe>/Output_PressureCalibration bzw. Output_MassTransfer.
% Dateiname aus der ersten Zeile je Messart (Befund F08).
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

    for art = unique(alle.Messart)'
        teil = alle(string(alle.Messart) == string(art), :);
        if string(art) == "Druckkalibrierung"
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
