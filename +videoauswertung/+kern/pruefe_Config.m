function pruefe_Config(cfg)
% PRUEFE_CONFIG Bricht mit einer klaren Meldung ab, wenn cfg unplausibel ist.
%
% Wird zu Beginn jeder Auswertung aufgerufen (Skript und GUI).
%
% Parameter
% ---------
% cfg : struct aus config()

    pruefe(cfg.video.fps > 0, 'cfg.video.fps muss positiv sein (z. B. 200).');
    pruefe(all(cfg.detektion.sens >= 0 & cfg.detektion.sens <= 1), ...
        'cfg.detektion.sens muss zwischen 0 und 1 liegen.');
    pruefe(cfg.detektion.min_slug_px >= 0, 'cfg.detektion.min_slug_px darf nicht negativ sein.');
    pruefe(cfg.detektion.min_flaeche_px >= 0, 'cfg.detektion.min_flaeche_px darf nicht negativ sein.');
    pruefe(cfg.tracking.max_sprung_px > 0, 'cfg.tracking.max_sprung_px muss größer als 0 sein.');
    pruefe(cfg.tracking.min_frames >= 1, 'cfg.tracking.min_frames muss mindestens 1 sein.');
    pruefe(cfg.physik.bin_mm > 0, 'cfg.physik.bin_mm muss größer als 0 sein.');
    pruefe(cfg.kalibrierung.rasterweite_mm > 0, 'cfg.kalibrierung.rasterweite_mm muss größer als 0 sein.');
    pruefe(isfile(cfg.pfade.laborbuch), sprintf('Laborbuch nicht gefunden: %s', cfg.pfade.laborbuch));
end

function pruefe(bedingung, meldung)
    if ~(isnumeric(bedingung) || islogical(bedingung)) || ~all(bedingung)
        error('videoauswertung:config', '%s', meldung);
    end
end
