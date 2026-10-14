function z = lies_Laborbuchzeile(labor, m)
% LIES_LABORBUCHZEILE Pflichtangaben eines Messlaufs aus dem Laborbuch.
%
% Schlüssel ist die Spalte "Dateiname" (= Messlauf, siehe lies_Messlauf).
% Fehlt die Zeile oder eine Pflichtangabe, bricht die Funktion mit einer
% Meldung ab, die Spalte und Messlauf nennt.
%
% Parameter
% ---------
% labor : table aus lade_Laborbuch
% m : struct aus lies_Messlauf
%
% Rückgabe
% --------
% z : struct mit p_Pa (Umgebungsdruck [Pa]), temp_C (Umgebungstemperatur
%     [°C]), co2 (CO2-Anteil [-]), reaktor_cm (Kanallaenge [cm]),
%     offset_mm (Position des rechten Bildrands im Reaktor [mm])

    zeile = find(strcmp(string(labor.Dateiname), m.name));
    if isempty(zeile)
        error('videoauswertung:laborbuch', ...
            'Ordner "%s" wurde im Laborbuch (Spalte "Dateiname") nicht gefunden!', m.name);
    end
    zeile = zeile(1);
    z.p_Pa       = labor.Umgebungsdruck(zeile);
    z.temp_C     = labor.Umgebungstemperatur(zeile);
    z.co2        = labor.("CO2-Anteil")(zeile);
    z.reaktor_cm = labor.Kanallaenge(zeile);
    z.offset_mm  = labor.Offset(zeile);
    pflicht = {'p_Pa', 'Umgebungsdruck'; 'temp_C', 'Umgebungstemperatur'; 'co2', 'CO2-Anteil'; ...
               'reaktor_cm', 'Kanallaenge'; 'offset_mm', 'Offset'};
    for k = 1:size(pflicht, 1)
        w = z.(pflicht{k, 1});
        if ismissing(w) || isnan(w)
            error('videoauswertung:laborbuch', 'Im Laborbuch fehlt "%s" für den Ordner "%s"!', pflicht{k, 2}, m.name);
        end
    end
end
