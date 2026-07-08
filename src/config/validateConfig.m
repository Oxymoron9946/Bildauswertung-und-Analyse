function config = validateConfig(config)
% VALIDATECONFIG Prüft den Konfigurations-Struct auf physikalische und logische Fehler.
% Bricht mit einem klaren Fehler ab, falls ungültige Werte gefunden werden.

    % --- Video ---
    assert(isnumeric(config.video.fps) && config.video.fps > 0, ...
        'config.video.fps muss eine positive Zahl sein (z.B. 200).');

    % --- Detektion ---
    assert(isnumeric(config.detection.sens) && config.detection.sens >= 0 && config.detection.sens <= 1, ...
        'config.detection.sens muss zwischen 0 und 1 liegen.');
    assert(isnumeric(config.detection.minPixel) && config.detection.minPixel >= 0, ...
        'config.detection.minPixel darf nicht negativ sein.');
    assert(isnumeric(config.detection.minArea) && config.detection.minArea >= 0, ...
        'config.detection.minArea darf nicht negativ sein.');

    % --- Tracking ---
    assert(isnumeric(config.tracking.maxJumpDist_px) && config.tracking.maxJumpDist_px > 0, ...
        'config.tracking.maxJumpDist_px muss größer als 0 sein.');
    assert(isnumeric(config.tracking.minFramesTracked) && config.tracking.minFramesTracked >= 1, ...
        'config.tracking.minFramesTracked muss mindestens 1 sein.');

    % --- Physik ---
    assert(isnumeric(config.physics.binSize_mm) && config.physics.binSize_mm > 0, ...
        'config.physics.binSize_mm muss größer als 0 sein.');
end