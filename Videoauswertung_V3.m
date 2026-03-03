%% Videoauswertung_V14_UnitCell_Measurement.m
% (Auto-Thresh + Auto-Kalibrierung + Auto-ROI + Unit Cell Messung)
clc; close all; clear;

%% ----------------- Parameter -----------------
videoFile = '019002.avi';
fps = 200;

% --- Visualisierung An/Aus ---
showVisuals = true;             % Tracking-Visualisierung während der Berechnung anzeigen
showCalibrationImage = true;   % Das Bild der automatischen Kalibrierung zur Kontrolle anzeigen

% --- Filter für Flüssigkeits-Slugs (Sanduhren) ---
minPixel = 50;
minArea  = 100;
minSolid = 0.50; 
maxSolid = 0.98;
minEcc   = 0.05;
minAngle = 0;         
toleranceY = 0.1;

% Automatische Kanalhöhen-Schätzung
channelHeightEstimate = NaN;
firstFrameAnalyzed = false;
minHeightRatio = 0.4; % Das Objekt muss mindestens 22% der ROI-Höhe einnehmen

% --- Visualisierungs- & Tracking-Einstellungen ---
borderMargin = 2; 
visualizeEveryNFrames = 10;
dimOffsetY = 45;       
printEveryNFrames = 10;

%% ----------------- Video laden -----------------
v = VideoReader(videoFile);
firstFrame = readFrame(v);
v.CurrentTime = 0;
if ndims(firstFrame) == 3
    firstFrameGray = rgb2gray(firstFrame); 
else
    firstFrameGray = firstFrame; 
end
[imgH, imgW] = size(firstFrameGray);

%% ----------------- Automatische Kalibrierung (Pixel in mm) -----------------
px2mm = 1; % Fallback
searchStartY = floor(imgH * 0.30);
searchEndY   = floor(imgH * 0.60);
searchArea = firstFrameGray(searchStartY:searchEndY, :);

% Y-Höhe des Lineals finden
edgesV = edge(searchArea, 'sobel', 'vertical');
rowSumV = sum(edgesV, 2);
[~, bestY_local] = max(rowSumV); 
bestY = bestY_local + searchStartY - 1;

% Suchband ausschneiden
y_start = max(1, bestY - 40);
y_end   = min(imgH, bestY + 5);
x_margin = 25; 
rulerBand = double(firstFrameGray(y_start:y_end, x_margin:end-x_margin));

% 1D-Helligkeitsprofil und Peakerkennung
intensityProfile = mean(rulerBand, 1);
invertedProfile = max(intensityProfile) - intensityProfile;
smoothedProfile = smoothdata(invertedProfile, 'gaussian', 5);

prominenceThreshold = max(smoothedProfile) * 0.10; 
[pks, locs] = findpeaks(smoothedProfile, 'MinPeakDistance', 8, 'MinPeakProminence', prominenceThreshold);

if length(locs) >= 10
    peakDiffs = diff(locs);
    medianPx = median(peakDiffs);
    valid_mask = abs(peakDiffs - medianPx) < (0.25 * medianPx);
    
    props = regionprops(bwlabel(valid_mask), 'Area', 'PixelIdxList');
    if ~isempty(props)
        [~, maxIdx] = max([props.Area]);
        longestChainIdx = props(maxIdx).PixelIdxList;
        
        firstTick_X_local = locs(longestChainIdx(1));
        lastTick_X_local  = locs(longestChainIdx(end) + 1);
        
        numIntervals = length(longestChainIdx);
        calibDistance_mm = numIntervals * 0.525; 
        calibDistance_px = lastTick_X_local - firstTick_X_local;
        
        px2mm = calibDistance_mm / calibDistance_px;
        fprintf('\n--- Automatische Kalibrierung ---\n');
        fprintf('Faktor: %.5f mm/px (Gemessen über %.2f mm)\n', px2mm, calibDistance_mm);
        
        % Optionale visuelle Kontrolle
        if showCalibrationImage
            global_locs = locs + x_margin - 1;
            global_firstTick = firstTick_X_local + x_margin - 1;
            global_lastTick  = lastTick_X_local + x_margin - 1;
            
            hFigCalib = figure('Name', 'Kalibrierung Kontrolle');
            imshow(firstFrameGray, []); hold on;
            
            bandRect = [x_margin, y_start, imgW - 2*x_margin, y_end - y_start];
            rectangle('Position', bandRect, 'EdgeColor', 'y', 'LineStyle', '--', 'LineWidth', 1);
            plot(global_locs, repmat(bestY, size(global_locs)), 'r+', 'MarkerSize', 8, 'LineWidth', 1.5);
            plot([global_firstTick, global_lastTick], [bestY, bestY], 'go-', 'MarkerSize', 10, 'LineWidth', 2);
            title(sprintf('Suchband (gelb) | Messbereich (Grün): %.2f mm', calibDistance_mm));
            pause(2); % Zeigt das Bild 2 Sekunden und schließt es dann
            if isgraphics(hFigCalib), close(hFigCalib); end 
        end
    else
        warning('Kalibrierung fehlgeschlagen: Abstände unregelmäßig.');
    end
else
    warning('Kalibrierung fehlgeschlagen: Zu wenige Striche gefunden.');
end

%% ----------------- Automatische ROI Erkennung -----------------
lowerThirdStartY = floor(imgH * 2/3);
lowerThirdImg = firstFrameGray(lowerThirdStartY:end, :);

edgesH = edge(lowerThirdImg, 'sobel', 'horizontal');
borderIgnore = 40;
edgesH(1:borderIgnore, :) = 0; edgesH(end-borderIgnore+1:end, :) = 0;
edgesH(:, 1:borderIgnore) = 0; edgesH(:, end-borderIgnore+1:end) = 0;

rowSum = sum(edgesH, 2);
[~, locs] = findpeaks(rowSum, 'MinPeakDistance', 20, 'SortStr', 'descend');

if length(locs) >= 2
    y_lines = locs(1:2);
    y_top = min(y_lines) + lowerThirdStartY - 1;
    y_bottom = max(y_lines) + lowerThirdStartY - 1;
    
    padding = 10; 
    y0 = max(1, y_top - padding);
    y1 = min(imgH, y_bottom + padding);
    x0 = 1;
    x1 = imgW;
    fprintf('ROI erkannt: Y von %d bis %d\n\n', y0, y1);
else
    error('Konnte Kanal (ROI) nicht automatisch erkennen.');
end

%% ----------------- Frame Loop -----------------
totalFrames = v.NumFrames;
maxDetections = totalFrames * 35;  
res_frame   = zeros(maxDetections, 1); 
res_time_s  = zeros(maxDetections, 1); 
res_posIdx  = zeros(maxDetections, 1); 
res_len_px  = zeros(maxDetections, 1); 
res_len_mm  = zeros(maxDetections, 1); 
res_mid_x   = zeros(maxDetections, 1);

collected_UC_px = [];
collected_UC_mm = [];

dataIdx = 0;  
if showVisuals
    hFig = figure('Name','Tracking'); hAx = axes(hFig);
end
frameIdx = 0;

startTime = tic;
while hasFrame(v)
    frameIdx = frameIdx + 1;
    I_full = readFrame(v);
    
    if ndims(I_full) == 3, I_full = rgb2gray(I_full); end
    I = I_full(y0:y1, x0:x1);
    
    imgW = size(I, 2); 
    imgH = size(I, 1); 
    
    I_eq = adapthisteq(I, 'NumTiles', [4 8], 'ClipLimit', 0.01);
    level = graythresh(I_eq);
    B = imbinarize(I_eq, level);
    B = bwareaopen(B, minPixel);
    
    B = imfill(B, 'holes');

    [L, num] = bwlabel(B);
    if num < 2, continue; end
    
    statsBasic = regionprops(L, 'Area', 'BoundingBox');
    candidateIdx = find([statsBasic.Area] > minArea);
    if isempty(candidateIdx), continue; end
    
    if isempty(candidateIdx), continue; end

    % --- AUTOMATISCHE KANALHÖHEN-SCHÄTZUNG (nur im ersten Frame) ---
    if ~firstFrameAnalyzed
        candidateHeights = [statsBasic(candidateIdx).BoundingBox];
        candidateHeights = candidateHeights(4:4:end); % bb(4) = Höhe aller Kandidaten
    
        if length(candidateHeights) >= 4 % Mindestens 4 Kandidaten zum Clustern
            % Sortiere Höhen und nimm den Median der oberen Hälfte als Kanalhöhe
            sortedHeights = sort(candidateHeights);
            upperHalf = sortedHeights(ceil(length(sortedHeights)/2):end);
            channelHeightEstimate = median(upperHalf);
        
            fprintf('Kanalhöhe automatisch geschätzt: %.1f Pixel (Median obere Gruppe).\n', channelHeightEstimate);
            firstFrameAnalyzed = true;
        end
    end

    statsFull = regionprops(L, 'Solidity', 'Eccentricity', 'Orientation', 'Centroid');
    
    det = struct('cx',{},'cy',{},'leftX',{},'leftY',{},'rightX',{},'rightY',{},'bb',{});
    for k = candidateIdx
        bb = statsBasic(k).BoundingBox;
        objHeight = bb(4);
        
            % Intelligenter Höhenfilter (automatisch angepasst)
        if ~isnan(channelHeightEstimate)
            % Objekt muss mindestens 70% der automatisch geschätzten Kanalhöhe haben
            if objHeight < 0.80 * channelHeightEstimate
                continue; % Zu flach → Blaseninnere
            end
        else
            % Fallback (falls Schätzung noch nicht möglich)
            if objHeight < (imgH * 0.20)
                continue;
            end
        end

        
        sol = statsFull(k).Solidity;
        ecc = statsFull(k).Eccentricity;
        ori = statsFull(k).Orientation;

        cy_local = statsFull(k).Centroid(2); % Y-Schwerpunkt des Objekts
            middle_Y = imgH / 2;                 % Mitte des ausgeschnittenen Kanals (ROI)
            
            % Erlaube eine Abweichung von max. 20% der Bildhöhe von der Mitte
            if abs(cy_local - middle_Y) > (imgH * 0.40)
                continue; % Objekt liegt zu weit oben oder unten (Störstruktur)
            end

        if (sol >= minSolid && sol <= maxSolid && ecc >= minEcc && abs(ori) >= minAngle)
            
            bx0 = max(1, floor(bb(1))); 
            by0 = max(1, floor(bb(2)));
            bx1 = min(imgW, ceil(bb(1)+bb(3)-1)); 
            by1 = min(imgH, ceil(bb(2)+bb(4)-1));
            
            if bx0 <= borderMargin || bx1 >= (imgW - borderMargin)
                continue; 
            end
            
            if bx1 <= bx0 || by1 <= by0, continue; end
            
            subL = L(by0:by1, bx0:bx1);
            maskSmall = (subL == k);
            
            perim = bwperim(maskSmall, 8);
            [rP, cP] = find(perim);
            if isempty(rP), continue; end
            
            cx_local = statsFull(k).Centroid(1) - bx0 + 1;
            
            spanY = max(rP) - min(rP);
            midY = (min(rP)+max(rP))/2;
            limitLow = midY - spanY*toleranceY;
            limitHigh = midY + spanY*toleranceY;
            inBand = (rP >= limitLow) & (rP <= limitHigh);
            cBand = cP(inBand);
            rBand = rP(inBand);
            
            if isempty(cBand), continue; end
            leftMask = cBand < cx_local;
            rightMask = cBand >= cx_local;
            if ~any(leftMask) || ~any(rightMask), continue; end
            
            cL = cBand(leftMask); rL = rBand(leftMask);
            cR = cBand(rightMask); rR = rBand(rightMask);
            
            left_x_local = max(cL); 
            right_x_local = min(cR);
            
            det(end+1) = struct('cx', statsFull(k).Centroid(1), 'cy', statsFull(k).Centroid(2), ...
                'leftX', left_x_local+bx0-1, 'leftY', round(mean(rL(cL==left_x_local)))+by0-1, ...
                'rightX', right_x_local+bx0-1, 'rightY', round(mean(rR(cR==right_x_local)))+by0-1, ...
                'bb', [bx0 by0 (bx1-bx0+1) (by1-by0+1)]); %#ok<AGROW>
        end
    end
    [~, sIdx] = sort([det.cx], 'descend');
    det = det(sIdx); 
    nDet = numel(det);
    
    if showVisuals && mod(frameIdx, visualizeEveryNFrames) == 0
        cla(hAx); imshow(I, [], 'Parent', hAx); hold(hAx, 'on'); 
        title(hAx, sprintf('Frame %d', frameIdx)); 
    end
    
    currentPosIdx = 1; 
    
    if nDet >= 2
        for j = 1:(nDet-1)
            bbLeft = det(j).bb; touchesLeft = bbLeft(1) <= borderMargin;
            bbRight = det(j+1).bb; touchesRight = (bbRight(1) + bbRight(3)) >= (imgW - borderMargin);
            
            if touchesLeft || touchesRight
                if showVisuals && mod(frameIdx, visualizeEveryNFrames) == 0
                   rectangle(hAx, 'Position', bbLeft, 'EdgeColor', [0.5 0 0], 'LineStyle', ':');
                   rectangle(hAx, 'Position', bbRight, 'EdgeColor', [0.5 0 0], 'LineStyle', ':');
                end
                continue; 
            end
            
            x_e = det(j+1).rightX;  % Rechte Kante des linken Slugs
            x_s = det(j).leftX;     % Linke Kante des rechten Slugs
            len_px = x_s - x_e;     % Länge der Blase dazwischen

            if len_px <= 0, continue; end

            len_mm = len_px * px2mm;
            mid_x = (x_e + x_s)/2;

            if length(collected_UC_px) < 2
                % Unit Cell: Abstand zwischen linker Kante Slug j und linker Kante Slug j+1
                uc_px = abs(det(j).leftX - det(j+1).leftX); 
                collected_UC_px(end+1) = uc_px;
                collected_UC_mm(end+1) = uc_px * px2mm;
            end
            
            dataIdx = dataIdx + 1;
            res_frame(dataIdx)   = frameIdx;
            res_time_s(dataIdx)  = (frameIdx-1)/fps;
            res_posIdx(dataIdx)  = currentPosIdx;
            res_len_px(dataIdx)  = len_px;
            res_len_mm(dataIdx)  = len_mm; 
            res_mid_x(dataIdx)   = mid_x;
            
            if showVisuals && mod(frameIdx, visualizeEveryNFrames) == 0
                y_e = det(j).rightY; y_s = det(j+1).leftY;
                dim_y = min(y_e, y_s) - dimOffsetY;
                
                plot(hAx, [x_e, x_e], [y_e, dim_y], 'm:', 'LineWidth', 1.5);
                plot(hAx, [x_s, x_s], [y_s, dim_y], 'm:', 'LineWidth', 1.5);
                plot(hAx, [x_e, x_s], [dim_y, dim_y], 'm-', 'LineWidth', 2);
               % Länge der Blase an der Maßlinie
                labelStr = sprintf('%.2f \n mm', len_mm);
                text(hAx, mid_x, dim_y-15, labelStr, 'Color','m','FontWeight','bold','HorizontalAlignment','center');
                
                % Index der Blase DIREKT ÜBER der Längenangabe positionieren
                % dim_y ist die Y-Höhe der horizontalen Linie. -40 rückt den Text noch weiter nach oben (im Bild)
                text(hAx, mid_x, dim_y-40, sprintf('#%d', currentPosIdx), ...
                    'Color','c','FontSize',9,'FontWeight','bold','HorizontalAlignment','center');
            end
            currentPosIdx = currentPosIdx + 1; 
        end
    end
    
    if showVisuals && mod(frameIdx, visualizeEveryNFrames) == 0
        hold(hAx, 'off'); drawnow; 
    end
    
    if mod(frameIdx, 100) == 0
        elapsedSoFar = toc(startTime);
        framesPerSec = frameIdx / elapsedSoFar;
        fprintf('Frame %d | Zeit: %.1fs | %.1f FPS | Geschätzt gesamt: %.1fs\n', ...
                frameIdx, elapsedSoFar, framesPerSec, frameIdx / framesPerSec);
    end
end
% --- Zeitmessung ENDE ---
elapsedTime = toc(startTime);
fprintf('\nDauer der Berechnung: %.2f Sekunden (%.2f FPS)\n', elapsedTime, frameIdx/elapsedTime);

% Arrays auf tatsächliche Größe trimmen
res_frame  = res_frame(1:dataIdx);
res_time_s = res_time_s(1:dataIdx);
res_posIdx = res_posIdx(1:dataIdx);
res_len_px = res_len_px(1:dataIdx);
res_len_mm = res_len_mm(1:dataIdx);
res_mid_x  = res_mid_x(1:dataIdx);

%% ----------------- Statistik & Unit Cell Auswertung -----------------
if length(collected_UC_mm) >= 2
    avg_UC_mm = mean(collected_UC_mm(1:2));
    avg_UC_px = mean(collected_UC_px(1:2));
    fprintf('--- Unit Cell (UC) Auswertung ---\n');
    fprintf('Mittelwert der Unit Cell Länge (L_uc): %.3f mm (%.0f px)\n', avg_UC_mm, avg_UC_px);
end

if isempty(res_frame)
    warning('Keine Blasen-Daten vorhanden.'); return;
end

TBL = table(res_frame, res_time_s, res_posIdx, res_len_px, res_len_mm, res_mid_x, ...
    'VariableNames', {'Frame','Time_s','Position','Len_px','Len_mm','MidX'});
stats = grpstats(TBL, 'Position', {'mean', 'std', 'numel'}, 'DataVars', {'Len_px', 'Len_mm'});
disp(stats(:, {'mean_Len_mm', 'std_Len_mm', 'numel_Len_mm'}));

figure('Name', 'Statistik');
errorbar(stats.Position, stats.mean_Len_mm, stats.std_Len_mm, '-s', 'LineWidth', 1.5, 'MarkerSize', 8, 'MarkerFaceColor', 'c', 'Color', 'b');
xlabel('Blasen-Position im Bild (1 = Eintritt ganz rechts)'); ylabel('Mittlere Blasenlänge [mm]');
title('Mittlere Blasenlänge'); grid on; xticks(stats.Position);

writetable(stats, 'Statistik_Ergebnisse.csv');
