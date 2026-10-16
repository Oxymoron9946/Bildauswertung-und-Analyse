function [px2mm, ok, info] = kalibriere_Massstab(frame, cfg)
% KALIBRIERE_MASSSTAB Bestimmt den Maßstab aus dem Lineal im Kalibrierbild.
%
% Ablauf: Im vertikalen Suchstreifen liegt die Zeile mit den meisten
% vertikalen Sobel-Kanten auf dem Lineal. Über ein Band um diese Zeile
% wird das Helligkeitsprofil gemittelt, invertiert und geglättet; seine
% Spitzen sind die Linealstriche. Die längste Kette von Strichen mit
% gleichmäßigem Abstand (± cfg.kalibrierung.raster_toleranz_rel um den
% Median) ergibt: px2mm = Intervalle · rasterweite_mm / Abstand_px.
%
% Parameter
% ---------
% frame : Grauwertbild (erstes Frame des Kalibriervideos)
% cfg : struct aus config()
%
% Rückgabe
% --------
% px2mm : Maßstab [mm/px], NaN bei Fehlschlag
% ok : logisch, Kalibrierung erfolgreich
% info : struct für die Kontrollabbildung (bestY, band, striche_x,
%        erster_x, letzter_x, strecke_mm) [px]

    k = cfg.kalibrierung;
    [imgH, imgW] = size(frame);
    px2mm = NaN;
    ok = false;
    info = struct('bestY', NaN, 'band', [], 'striche_x', [], 'erster_x', NaN, ...
        'letzter_x', NaN, 'strecke_mm', NaN, 'bildlaenge_mm', NaN);

    y0 = floor(imgH * k.suchbereich_rel(1));
    y1 = floor(imgH * k.suchbereich_rel(2));
    zeilensumme = sum(edge(frame(y0:y1, :), 'sobel', 'vertical'), 2);
    [~, bestY_lokal] = max(zeilensumme);
    bestY = bestY_lokal + y0 - 1;

    band_y0 = max(1, bestY - k.band_oben_px);
    band_y1 = min(imgH, bestY + k.band_unten_px);
    rand = k.rand_px;
    band = double(frame(band_y0:band_y1, rand:end-rand));

    profil = mean(band, 1);
    profil = smoothdata(max(profil) - profil, 'gaussian', k.glaettung_px);
    [~, striche] = findpeaks(profil, 'MinPeakDistance', k.min_strichabstand_px, ...
        'MinPeakProminence', max(profil) * k.prominenz_rel);

    info.bestY = bestY;
    info.band = [rand, band_y0, imgW - 2*rand, band_y1 - band_y0];
    if length(striche) < k.min_striche
        return;
    end

    abstaende = diff(striche);
    median_px = median(abstaende);
    regelmaessig = abs(abstaende - median_px) < (k.raster_toleranz_rel * median_px);
    ketten = regionprops(bwlabel(regelmaessig), 'Area', 'PixelIdxList');
    if isempty(ketten)
        return;
    end
    [~, laengste] = max([ketten.Area]);
    kette = ketten(laengste).PixelIdxList;

    strecke_mm = length(kette) * k.rasterweite_mm;
    erster = striche(kette(1));
    letzter = striche(kette(end) + 1);
    strecke_px = letzter - erster;
    if strecke_px <= 0
        return;
    end

    px2mm = strecke_mm / strecke_px;
    ok = true;
    info.striche_x = striche(kette) + rand - 1;
    info.erster_x = erster + rand - 1;
    info.letzter_x = letzter + rand - 1;
    info.strecke_mm = strecke_mm;
    info.bildlaenge_mm = imgW * px2mm;
end
