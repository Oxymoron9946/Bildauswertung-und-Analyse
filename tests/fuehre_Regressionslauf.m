function T = fuehre_Regressionslauf(art, ziel, ausgabe)
% FUEHRE_REGRESSIONSLAUF Wertet ein Regressionsziel aus und liest das Ergebnis.
%
% Parameter
% ---------
% art : 'batch' (Messordner) oder 'einzel' (Aufnahmeordner mit einem Video)
% ziel : absoluter Pfad
% ausgabe : leerer Ordner für die erzeugten CSV-Dateien
%
% Rückgabe
% --------
% T : Ergebnistabelle, gelesen aus der erzeugten CSV (alle Spalten als Text)

    cfg = config();
    cfg.pfade.ausgabe = ausgabe;

    switch art
        case 'batch'
            dateien = videoauswertung.kern.auswerten_Batch(cfg, ziel);
        case 'einzel'
            video = dir(fullfile(ziel, cfg.video.dateimuster));
            assert(isscalar(video), 'Im Aufnahmeordner muss genau ein Video liegen: %s', ziel);
            dateien = {videoauswertung.kern.auswerten_Einzel(cfg, fullfile(video.folder, video.name))};
        otherwise
            error('Unbekannte Art: %s', art);
    end

    assert(isscalar(dateien), 'Erwartet genau eine Ergebnis-CSV, erhalten: %d', numel(dateien));
    opts = detectImportOptions(dateien{1}, 'TextType', 'string', 'VariableNamingRule', 'preserve');
    T = readtable(dateien{1}, setvartype(opts, 'string'));
end
