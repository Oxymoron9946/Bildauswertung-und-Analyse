function dateien = wiederhole_Lauf(datei, ausgabe)
% WIEDERHOLE_LAUF Führt einen früheren Lauf (z. B. aus der GUI) per Skript erneut aus.
%
% Beispiel
% --------
%   videoauswertung.kern.wiederhole_Lauf('output/lauf_config_20261014_201500.json')
%
% Parameter
% ---------
% datei : lauf_config_<Zeit>.json
% ausgabe : optional, anderer Ausgabeordner (sonst der gespeicherte)
%
% Rückgabe
% --------
% dateien : cellstr der geschriebenen CSV-Dateien

    [cfg, lauf] = videoauswertung.io.lade_Laufconfig(datei);
    if nargin >= 2 && ~isempty(ausgabe)
        cfg.pfade.ausgabe = ausgabe;
    end
    cfg.anzeige.live = false;
    cfg.anzeige.kalibrierung = false;
    fprintf('Wiederhole Lauf vom %s (%s): %s\n', lauf.zeit, lauf.art, lauf.ziel);
    switch lauf.art
        case 'batch'
            dateien = videoauswertung.kern.auswerten_Batch(cfg, lauf.ziel);
        case 'einzel'
            dateien = {videoauswertung.kern.auswerten_Einzel(cfg, lauf.ziel)};
        otherwise
            error('videoauswertung:laufconfig', 'Unbekannte Laufart: %s', lauf.art);
    end
end
