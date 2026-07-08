function labTable = load_Laborbuch(csvPath)
% LOAD_LABORBUCH Liest die Laborbuch-CSV-Datei ein und prüft deren Existenz.
%
% Eingabe:
%   csvPath - Absoluter Pfad zur Laborbuch.csv
%
% Ausgabe:
%   labTable - MATLAB Table mit den Metadaten (VariableNamingRule = 'preserve')

    fprintf('--- Lade Konfigurationsdateien ---\n');
    
    if ~isfile(csvPath)
        error('Laborbuch nicht gefunden unter: %s', csvPath);
    end
    
    labTable = readtable(csvPath, 'Delimiter', ';', 'VariableNamingRule', 'preserve');
    fprintf('Laborbuch geladen: %d Einträge gefunden.\n', height(labTable));
    fprintf('----------------------------------\n\n');
end
