function [px2mm, calibSuccess] = setup_Calibration(firstFrameGray, showCalibrationImage)
% SETUP_CALIBRATION Ermittelt Massstab aus dem ersten Frame der Kalibrierdatei.
%
% Eingaben:
%   firstFrameGray       - Das erste Frame des Videos als Grauwertbild
%   showCalibrationImage - Boolean, ob das Kontrollbild angezeigt werden soll
%
% Rueckgaben:
%   px2mm - Umrechnungsfaktor (mm pro Pixel) (NaN falls fehlerhaft)
%   calibSuccess - Boolean, ob die Kalibrierung erfolgreich war
%
% AUFRUFER: main_Batch (showCalibrationImage=false), main_einzel (oft true zum Prüfen).
% ALGORITHMUS-KERN: horizontale Tick-Kette auf Lineal → bekannte Rasterweite
% 0.525 mm pro Intervall → mm/px. Ausführliche numerische Schwellen siehe Kommentare
% in Abschnitt 2 (für die Arbeit ggf. verkürzt darstellen).

    %% 1. Initialisierung
    [imgH_full, imgW_full] = size(firstFrameGray);
    px2mm = NaN; % Standardwert bei Fehler
    % roi = struct();
    calibSuccess = false;

    %% 2. Automatische Kalibrierung (Lineal-Erkennung)
    % Ablauf: vertikaler Suchstreifen → Zeile mit stärksten vertikalen Kanten
    % (Sobel) → horizontales Band um diese Y-Lage → Mittelung über Y im Band
    % → invertieren + Glättung → Peaks = Ticks → längste Kette ähnlicher
    % Peak-Abstände → mm aus 0.525 * Anzahl_Intervalle, px aus Tick-Pixeldifferenz.
    %
    % Suchbereich fuer das Lineal (vertikale Mitte des oberen Bildteils)
    searchStartY = floor(imgH_full * 0.30);
    searchEndY   = floor(imgH_full * 0.80);
    searchArea   = firstFrameGray(searchStartY:searchEndY, :);

    % Vertikale Kanten zur Identifikation der Lineal-Ticks suchen
    edgesV  = edge(searchArea, 'sobel', 'vertical');
    rowSumV = sum(edgesV, 2);
    [~, bestY_local] = max(rowSumV); 
    bestY = bestY_local + searchStartY - 1;

    % Band um die beste Y-Position definieren
    y_start  = max(1, bestY - 60); 
    y_end    = min(imgH_full, bestY + 15); 
    x_margin = 25; 
    rulerBand = double(firstFrameGray(y_start:y_end, x_margin:end-x_margin));

    % Intensitaetsprofil glaetten und invertieren (Peaks = Ticks)
    intensityProfile = mean(rulerBand, 1);
    invertedProfile  = max(intensityProfile) - intensityProfile;
    smoothedProfile  = smoothdata(invertedProfile, 'gaussian', 5);

    % Ticks ueber Prominenz-Schwellenwert filtern
    prominenceThreshold = max(smoothedProfile) * 0.10; 
    [~, locs] = findpeaks(smoothedProfile, 'MinPeakDistance', 8, 'MinPeakProminence', prominenceThreshold);

    if length(locs) >= 10
        % Abstaende zwischen den Peaks pruefen, um das konstante Raster zu finden
        peakDiffs = diff(locs); 
        medianPx  = median(peakDiffs);
        valid_mask = abs(peakDiffs - medianPx) < (0.25 * medianPx);
        props = regionprops(bwlabel(valid_mask), 'Area', 'PixelIdxList');

        if ~isempty(props)
            % Laengste ununterbrochene Kette von validen Abstaenden waehlen
            [~, maxIdx] = max([props.Area]); 
            longestChainIdx = props(maxIdx).PixelIdxList;
            numIntervals = length(longestChainIdx);

            % Lineal-Einteilung: 0.525 mm pro Intervall (Kalibriermass)
            calibDistance_mm = numIntervals * 0.525; 

            % Abstand in Pixeln zwischen erstem und letztem Tick der Kette
            firstTick_X_local = locs(longestChainIdx(1));
            lastTick_X_local  = locs(longestChainIdx(end) + 1);
            calibDistance_px  = lastTick_X_local - firstTick_X_local;

            % Massstab berechnen
            if calibDistance_px > 0
                px2mm = calibDistance_mm / calibDistance_px;
                calibSuccess = true;

                % Globale Koordinaten fuer Visualisierung sichern
                global_locs      = locs(longestChainIdx) + x_margin - 1;
                global_firstTick = firstTick_X_local + x_margin - 1;
                global_lastTick  = lastTick_X_local + x_margin - 1;
                totalImageLength_mm = imgW_full * px2mm;
                if showCalibrationImage
                    fprintf('=> Gesamte angezeigte Bildlaenge: %.2f mm\n', totalImageLength_mm);
                end
            end
        end
    end

    if ~calibSuccess
        if showCalibrationImage
            warning('Kalibrierung des Massstabs fehlgeschlagen. px2mm auf NaN gesetzt.');
        end
    end

    % %% 3. Automatische ROI-Erkennung (Kanalwaende) — DEAKTIVIERT (historischer Entwurf)
    % Wäre aktiv, würde roi aus unterem Bilddrittel schätzen; wird vom Batch nicht
    % genutzt (ROI kommt später aus Vollbild / detect_Bubbles-Kontext).
    % % Der Kanal befindet sich im unteren Drittel des Bildes
    % lowerThirdStartY = floor(imgH_full * 2/3);
    % lowerThirdImg    = firstFrameGray(lowerThirdStartY:end, :);
    % 
    % % Horizontale Kanten fuer Kanalwaende suchen
    % edgesH = edge(lowerThirdImg, 'sobel', 'horizontal');
    % borderIgnore = 35; % Bildraender ignorieren, um Artefakte zu meiden
    % 
    % % Raender im Kantenbild auf 0 setzen
    % edgesH(1:borderIgnore, :) = 0; 
    % edgesH(end-borderIgnore+1:end, :) = 0;
    % edgesH(:, 1:borderIgnore) = 0; 
    % edgesH(:, end-borderIgnore+1:end) = 0;
    % 
    % % Projektion der Kanten auf die Y-Achse
    % rowSum = sum(edgesH, 2);
    % [~, locs_roi] = findpeaks(rowSum, 'MinPeakDistance', 20, 'SortStr', 'descend');
    % 
    % if length(locs_roi) >= 2
    %     % Die zwei markantesten Linien sind die Kanalwaende
    %     y_lines  = locs_roi(1:2);
    %     y_top    = min(y_lines) + lowerThirdStartY - 1;
    %     y_bottom = max(y_lines) + lowerThirdStartY - 1;
    % 
    %     % Asymmetrische Korrektur der erkannten Kanten
    %     y_top_corrected    = y_top - 1; 
    %     y_bottom_corrected = y_bottom + 0; 
    % 
    %     padding = 8; 
    %     roi.y0 = max(1, y_top_corrected - padding);
    %     roi.y1 = min(imgH_full, y_bottom_corrected + padding);
    %     roi.x0 = 1; 
    %     roi.x1 = imgW_full;
    % else
    %     warning('Kanal (ROI) konnte nicht zuverlaessig erkannt werden.');
    %     calibSuccess = false; % Wenn ROI fehlt, gilt Kalibrierung insgesamt als fehlgeschlagen
    % end

    %% 4. Visuelle Kontrolle (Nur falls angefordert)
    % 5 s Pause, dann Fenster schließen — für Batch unüblich (immer false).
    if showCalibrationImage
        hFigCalib = figure('Name', 'Kalibrierung Kontrolle');
        imshow(firstFrameGray, []); hold on;

        if calibSuccess
            % Kalibrier-Band und gefundene Ticks
            bandRect = [x_margin, y_start, imgW_full - 2*x_margin, y_end - y_start];
            rectangle('Position', bandRect, 'EdgeColor', 'y', 'LineStyle', '--', 'LineWidth', 1);
            plot(global_locs, repmat(bestY, size(global_locs)), 'r+', 'MarkerSize', 8, 'LineWidth', 1.5);
            plot([global_firstTick, global_lastTick], [bestY, bestY], 'go-', 'MarkerSize', 10, 'LineWidth', 2);
            title(sprintf('Massstab: %.5f mm/px | Messbereich: %.2f mm', px2mm, calibDistance_mm));
            title(sprintf('Massstab: %.5f mm/px | Messbereich: %.2f mm | Bildlaenge: %.2f mm', px2mm, calibDistance_mm, totalImageLength_mm));
        else
            title('KALIBRIERUNG FEHLGESCHLAGEN!', 'Color', 'r');
        end

        pause(5);
        if isgraphics(hFigCalib), close(hFigCalib); end
    end
end

