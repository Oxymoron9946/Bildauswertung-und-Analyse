function [px2mm, roi, calibSuccess] = setup_Calibration(firstFrameGray, showCalibrationImage)
    % setup_Calibration - Ermittelt Maßstab und Kanal-ROI aus dem ersten Frame.
    %
    % Eingaben:
    %   firstFrameGray       - Das erste Frame des Videos als Grauwertbild
    %   showCalibrationImage - Boolean, ob das Kontrollbild angezeigt werden soll
    %
    % Rückgaben:
    %   px2mm        - Umrechnungsfaktor (mm pro Pixel)
    %   roi          - Struct mit den Grenzen {y0, y1, x0, x1}
    %   calibSuccess - Boolean, ob die Kalibrierung erfolgreich war

    [imgH_full, imgW_full] = size(firstFrameGray);
    px2mm = 1; % Fallback
    calibSuccess = false;

    %% 1. Automatische Kalibrierung (Lineal-Erkennung)
    searchStartY = floor(imgH_full * 0.30);
    searchEndY = floor(imgH_full * 0.60);
    searchArea = firstFrameGray(searchStartY:searchEndY, :);
    
    edgesV = edge(searchArea, 'sobel', 'vertical');
    rowSumV = sum(edgesV, 2);
    [~, bestY_local] = max(rowSumV); 
    bestY = bestY_local + searchStartY - 1;

    y_start = max(1, bestY - 40); 
    y_end = min(imgH_full, bestY + 5); 
    x_margin = 25; 
    rulerBand = double(firstFrameGray(y_start:y_end, x_margin:end-x_margin));
    
    intensityProfile = mean(rulerBand, 1);
    invertedProfile = max(intensityProfile) - intensityProfile;
    smoothedProfile = smoothdata(invertedProfile, 'gaussian', 5);

    prominenceThreshold = max(smoothedProfile) * 0.10; 
    [~, locs] = findpeaks(smoothedProfile, 'MinPeakDistance', 8, 'MinPeakProminence', prominenceThreshold);

    if length(locs) >= 10
        peakDiffs = diff(locs); 
        medianPx = median(peakDiffs);
        valid_mask = abs(peakDiffs - medianPx) < (0.25 * medianPx);
        props = regionprops(bwlabel(valid_mask), 'Area', 'PixelIdxList');
        
        if ~isempty(props)
            [~, maxIdx] = max([props.Area]); 
            longestChainIdx = props(maxIdx).PixelIdxList;
            numIntervals = length(longestChainIdx);
            calibDistance_mm = numIntervals * 0.525; 

            firstTick_X_local = locs(longestChainIdx(1));
            lastTick_X_local = locs(longestChainIdx(end) + 1);
            calibDistance_px = lastTick_X_local - firstTick_X_local;

            px2mm = calibDistance_mm / calibDistance_px;
            calibSuccess = true;
            
            global_locs = locs(longestChainIdx) + x_margin - 1;
            global_firstTick = firstTick_X_local + x_margin - 1;
            global_lastTick = lastTick_X_local + x_margin - 1;
        end
    end

    %% 2. Automatische ROI-Erkennung (Asymmetrisch)
    lowerThirdStartY = floor(imgH_full * 2/3);
    lowerThirdImg = firstFrameGray(lowerThirdStartY:end, :);
    
    edgesH = edge(lowerThirdImg, 'sobel', 'horizontal');
    borderIgnore = 35;
    edgesH(1:borderIgnore, :) = 0; edgesH(end-borderIgnore+1:end, :) = 0;
    edgesH(:, 1:borderIgnore) = 0; edgesH(:, end-borderIgnore+1:end) = 0;
    
    rowSum = sum(edgesH, 2);
    [~, locs_roi] = findpeaks(rowSum, 'MinPeakDistance', 20, 'SortStr', 'descend');

    if length(locs_roi) >= 2
        y_lines = locs_roi(1:2);
        y_top = min(y_lines) + lowerThirdStartY - 1;
        y_bottom = max(y_lines) + lowerThirdStartY - 1;

        y_top_corrected = y_top - 4; 
        y_bottom_corrected = y_bottom + 0; 

        padding = 8; 
        roi.y0 = max(1, y_top_corrected - padding);
        roi.y1 = min(imgH_full, y_bottom_corrected + padding);
        roi.x0 = 1; 
        roi.x1 = imgW_full;
    else
        error('Konnte Kanal (ROI) nicht erkennen.');
    end

    %% 3. Visuelle Kontrolle
    if showCalibrationImage
        hFigCalib = figure('Name', 'Kalibrierung & ROI Kontrolle');
        imshow(firstFrameGray, []); hold on;

        % Kanal-Kanten und ROI
        plot([1, imgW_full], [y_top, y_top], 'c-', 'LineWidth', 1.5);
        plot([1, imgW_full], [y_bottom, y_bottom], 'c-', 'LineWidth', 1.5);
        plot([1, imgW_full], [roi.y0, roi.y0], 'm--', 'LineWidth', 1);
        plot([1, imgW_full], [roi.y1, roi.y1], 'm--', 'LineWidth', 1);

        if calibSuccess
            bandRect = [x_margin, y_start, imgW_full - 2*x_margin, y_end - y_start];
            rectangle('Position', bandRect, 'EdgeColor', 'y', 'LineStyle', '--', 'LineWidth', 1);
            plot(global_locs, repmat(bestY, size(global_locs)), 'r+', 'MarkerSize', 8, 'LineWidth', 1.5);
            plot([global_firstTick, global_lastTick], [bestY, bestY], 'go-', 'MarkerSize', 10, 'LineWidth', 2);
            title(sprintf('Maßstab: %.5f mm/px | Messbereich: %.2f mm', px2mm, calibDistance_mm));
        else
            title('ROI erkannt | KALIBRIERUNG FEHLGESCHLAGEN!', 'Color', 'r');
        end

        pause(5); 
        if isgraphics(hFigCalib), close(hFigCalib); end 
    end
end
