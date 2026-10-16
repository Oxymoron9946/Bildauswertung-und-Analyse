function labor = lade_Laborbuch(datei)
% LADE_LABORBUCH Liest das Laborbuch (CSV, Semikolon) mit unveränderten Spaltennamen.
%
% Parameter
% ---------
% datei : Pfad zur Laborbuch-CSV (cfg.pfade.laborbuch)
%
% Rückgabe
% --------
% labor : table, eine Zeile je Messlauf; Schlüssel ist die Spalte "Dateiname"

    if ~isfile(datei)
        error('videoauswertung:laborbuchFehlt', 'Laborbuch nicht gefunden unter: %s', datei);
    end
    labor = readtable(datei, 'Delimiter', ';', 'VariableNamingRule', 'preserve');
    fprintf('Laborbuch geladen: %d Einträge gefunden.\n', height(labor));
end
