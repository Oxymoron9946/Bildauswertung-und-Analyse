function datei = exportiere_Einzel(tabelle, m, ausgabe)
% EXPORTIERE_EINZEL Schreibt das Ergebnis einer Einzelauswertung als CSV (Semikolon, Spalten wie im Batch).
%
% Datei: <ausgabe>/Output_PressureCalibration/Analysis_Pressure_<Messlauf>_<Aufnahme>.csv
%    bzw. <ausgabe>/Output_MassTransfer/Analysis_Mass_<Messlauf>_<Aufnahme>.csv
%
% Parameter
% ---------
% tabelle : Bins mit Metadaten (werte_Messvideo)
% m : struct aus lies_Messlauf
% ausgabe : Ausgabeordner (cfg.pfade.ausgabe)
%
% Rückgabe
% --------
% datei : Pfad der geschriebenen Datei

    if m.messart == "Druckkalibrierung"
        ordner = fullfile(ausgabe, 'Output_PressureCalibration');
        praefix = 'Analysis_Pressure_';
    else
        ordner = fullfile(ausgabe, 'Output_MassTransfer');
        praefix = 'Analysis_Mass_';
    end
    if ~isfolder(ordner)
        mkdir(ordner);
    end
    name = m.name;
    if strlength(m.aufnahme) > 0
        name = sprintf('%s_%s', name, m.aufnahme);
    end
    datei = fullfile(ordner, sprintf('%s%s.csv', praefix, name));
    writetable(tabelle, datei, 'Delimiter', ';');
    fprintf('Gesamtergebnis gespeichert unter: %s\n', datei);
end
