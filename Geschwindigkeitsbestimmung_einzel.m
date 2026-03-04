%% Einzel-Videoauswertung - GESCHWINDIGKEITS-MESSUNG mit Live-Tracking
clc; close all; clear;

%% ----------------- 1. Parameter -----------------
% Trage hier den Pfad zu deinem 500fps Video ein
videoFile = 'Test\test5002.avi';
fps = 500; % ACHTUNG: Auf 500 setzen für Geschwindigkeitsvideos!

% --- Visualisierung ---
showVisuals = true; % Live-Tracking anzeigen
visualizeEveryNFrames = 1; % Nur jeden 10. Frame zeichnen (für Performance)
showCalibrationImage = true; % Kontrollbild für Kalibrierung & ROI zeigen

% --- Filter für Flüssigkeits-Slugs ---
minPixel = 50;
minArea = 100;
minSolid = 0.50; 
maxSolid = 0.98;
minEcc = 0.05;
minAngle = 0; 
minHeightRatio = 0.22; 

% Tracking Parameter
maxJumpDist_px = 50; % Maximale Pixel, die eine Blase in 1 Frame nach links springen darf
minFramesTracked = 10; % Eine Blase muss min. 10 Frames verfolgt werden für gültige Geschwindigkeit

%% ----------------- 2. Video laden & Kalibrierung -----------------
v = VideoReader(videoFile);
firstFrame = readFrame(v);
v.CurrentTime = 0;
if ndims(firstFrame) == 3, firstFrameGray = rgb2gray(firstFrame); else, firstFrameGray = firstFrame; end
[imgH_full, imgW_full] = size(firstFrameGray); 

% Physik-Zeit
dt_frame = 1 / fps; 

% --- Kalibrierung ---
px2mm = 1; 
searchStartY = floor(imgH_full * 0.30);
searchEndY = floor(imgH_full * 0.60);
searchArea = firstFrameGray(searchStartY:searchEndY, :);
edgesV = edge(searchArea, 'sobel', 'vertical');
rowSumV = sum(edgesV, 2);
[~, bestY_local] = max(rowSumV); 
bestY = bestY_local + searchStartY - 1;

y_start = max(1, bestY - 40); y_end = min(imgH_full, bestY + 5); x_margin = 25; 
rulerBand = double(firstFrameGray(y_start:y_end, x_margin:end-x_margin));
intensityProfile = mean(rulerBand, 1);
invertedProfile = max(intensityProfile) - intensityProfile;
smoothedProfile = smoothdata(invertedProfile, 'gaussian', 5);

prominenceThreshold = max(smoothedProfile) * 0.10; 
[pks, locs] = findpeaks(smoothedProfile, 'MinPeakDistance', 8, 'MinPeakProminence', prominenceThreshold);
if length(locs) >= 10
    peakDiffs = diff(locs); medianPx = median(peakDiffs);
    valid_mask = abs(peakDiffs - medianPx) < (0.25 * medianPx);
    props = regionprops(bwlabel(valid_mask), 'Area', 'PixelIdxList');
    if ~isempty(props)
        [~, maxIdx] = max([props.Area]); longestChainIdx = props(maxIdx).PixelIdxList;
        numIntervals = length(longestChainIdx);
        calibDistance_mm = numIntervals * 0.525; 
        
        firstTick_X_local = locs(longestChainIdx(1));
        lastTick_X_local = locs(longestChainIdx(end) + 1);
        calibDistance_px = lastTick_X_local - firstTick_X_local;
        
        px2mm = calibDistance_mm / calibDistance_px;
        fprintf('Kalibrierung: %.5f mm/px\n', px2mm);
    end
end

% --- Automatische ROI (Asymmetrisch) ---
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
    
    y_top_corrected = y_top - 7; 
    y_bottom_corrected = y_bottom + 0; 
    
    padding = 8; 
    y0 = max(1, y_top_corrected - padding);
    y1 = min(imgH_full, y_bottom_corrected + padding);
    x0 = 1; x1 = imgW_full;
    fprintf('ROI erkannt: Y von %d bis %d\n\n', y0, y1);
    
    if showCalibrationImage
        hFigCalib = figure('Name', 'Kalibrierung & ROI Kontrolle');
        imshow(firstFrameGray, []); hold on;
        plot([1, imgW_full], [y_top, y_top], 'c-', 'LineWidth', 1.5);
        plot([1, imgW_full], [y_bottom, y_bottom], 'c-', 'LineWidth', 1.5);
        plot([1, imgW_full], [y0, y0], 'm--', 'LineWidth', 1);
        plot([1, imgW_full], [y1, y1], 'm--', 'LineWidth', 1);
        title('Kanal-Kanten (Cyan) | ROI (Magenta)');
        pause(3); 
        if isgraphics(hFigCalib), close(hFigCalib); end 
    end
else
    error('Konnte Kanal (ROI) nicht erkennen.');
end

%% ----------------- 3. Tracking Logik -----------------
v.CurrentTime = 0;

% Tracking: [ID, startFrame, start_midX_px, endFrame, end_midX_px]
bubbleTracker = []; 
nextBubbleID = 1;
prevBubbleCentroids = []; % [ID, midX]

% Kanalhöhen-Schätzung (identisch zur Längenauswertung)
channelHeightEstimate = NaN;
firstFrameAnalyzed = false;
borderMargin = 2;
toleranceY = 0.1;

if showVisuals
    hFig = figure('Name','Live Tracking Geschwindigkeit', 'Position', [100 200 1000 300]); 
    hAx = axes(hFig);
end

frameIdx = 0;
startTime = tic;

while hasFrame(v)
    frameIdx = frameIdx + 1;
    I_full = readFrame(v);
    if ndims(I_full) == 3, I_full = rgb2gray(I_full); end
    I = I_full(y0:y1, x0:x1);
    imgW = size(I, 2); imgH = size(I, 1); 

    I_eq = adapthisteq(I, 'NumTiles', [4 8], 'ClipLimit', 0.01);
    B = imbinarize(I_eq, graythresh(I_eq));
    B = imfill(B, 'holes');
    B = bwareaopen(B, minPixel);

    [L, num] = bwlabel(B);
    if num < 2, prevBubbleCentroids = []; continue; end

    statsBasic = regionprops(L, 'Area', 'BoundingBox');
    candidateIdx = find([statsBasic.Area] > minArea);
    if isempty(candidateIdx), prevBubbleCentroids = []; continue; end

    % --- Kanalhöhen-Schätzung (nur erstes Frame) ---
    if ~firstFrameAnalyzed
        candidateHeights = [statsBasic(candidateIdx).BoundingBox];
        candidateHeights = candidateHeights(4:4:end);
        if length(candidateHeights) >= 4
            sortedH = sort(candidateHeights);
            channelHeightEstimate = median(sortedH(ceil(end/2):end));
            firstFrameAnalyzed = true;
        end
    end

    statsFull = regionprops(L, 'Solidity', 'Eccentricity', 'Orientation', 'Centroid');

    % --- Slug-Erkennung (identisch zur Längenauswertung) ---
    det = struct('cx',{},'leftX',{},'rightX',{},'bb',{});
    for k = candidateIdx
        bb = statsBasic(k).BoundingBox;
        objHeight = bb(4);

        if ~isnan(channelHeightEstimate)
            if objHeight < 0.80 * channelHeightEstimate, continue; end
        else
            if objHeight < (imgH * 0.20), continue; end
        end

        cy_local = statsFull(k).Centroid(2);
        if abs(cy_local - imgH/2) > (imgH * 0.40), continue; end

        sol = statsFull(k).Solidity; ecc = statsFull(k).Eccentricity; ori = statsFull(k).Orientation;
        if ~(sol >= minSolid && sol <= maxSolid && ecc >= minEcc && abs(ori) >= minAngle), continue; end

        bx0 = max(1, floor(bb(1))); by0 = max(1, floor(bb(2)));
        bx1 = min(imgW, ceil(bb(1)+bb(3)-1)); by1 = min(imgH, ceil(bb(2)+bb(4)-1));
        if bx1 <= bx0 || by1 <= by0, continue; end

        % Rand-Kanten mit Perimeter bestimmen
        subL = L(by0:by1, bx0:bx1);
        maskSmall = (subL == k);
        perim = bwperim(maskSmall, 8);
        [rP, cP] = find(perim);
        if isempty(rP), continue; end

        cx_local = statsFull(k).Centroid(1) - bx0 + 1;
        spanY = max(rP) - min(rP);
        midY = (min(rP)+max(rP))/2;
        inBand = (rP >= midY - spanY*toleranceY) & (rP <= midY + spanY*toleranceY);
        cBand = cP(inBand); rBand = rP(inBand);
        if isempty(cBand), continue; end

        leftMask = cBand < cx_local; rightMask = cBand >= cx_local;
        if ~any(leftMask) || ~any(rightMask), continue; end

        left_x_local  = max(cBand(leftMask));
        right_x_local = min(cBand(rightMask));

        det(end+1) = struct( ...
            'cx',  statsFull(k).Centroid(1), ...
            'leftX',  left_x_local  + bx0 - 1, ...
            'rightX', right_x_local + bx0 - 1, ...
            'bb',  [bx0 by0 (bx1-bx0+1) (by1-by0+1)]); %#ok
    end

    if numel(det) < 2, prevBubbleCentroids = []; continue; end

    % Slugs von rechts nach links sortieren (Eintritt rechts)
    [~, sIdx] = sort([det.cx], 'descend');
    det = det(sIdx);
    nDet = numel(det);

    % --- Blasen-Mittelpunkte aus den Slug-Lücken extrahieren ---
    % NUR Blasen, bei denen BEIDE Nachbar-Slugs vollständig im Bild sind
    currentBubbleCentroids = []; % [midX, len_px] pro Blase dieses Frames

    if showVisuals && mod(frameIdx, visualizeEveryNFrames) == 0
        cla(hAx); imshow(I, [], 'Parent', hAx); hold(hAx, 'on');
        title(hAx, sprintf('Frame %d', frameIdx));
    end

    for j = 1:(nDet-1)
        bbLeft  = det(j).bb;
        bbRight = det(j+1).bb;
        
        % Prüfen ob BEIDE Slugs vollständig sichtbar (keine Berührung des Bildrandes)
        touchesLeft  = bbLeft(1) <= borderMargin;
        touchesRight = (bbRight(1) + bbRight(3)) >= (imgW - borderMargin);
        if touchesLeft || touchesRight, continue; end

        % Blasengrenze: Linke Kante des rechten Slugs bis rechte Kante des linken Slugs
        x_e = det(j+1).rightX;  % Rechte Kante des LINKEN (stromaufwärts) Slugs
        x_s = det(j).leftX;     % Linke Kante des RECHTEN (stromabwärts) Slugs
        len_px = x_s - x_e;
        if len_px <= 0, continue; end

        mid_x = (x_e + x_s) / 2;
        currentBubbleCentroids = [currentBubbleCentroids; mid_x, len_px]; %#ok

        if showVisuals && mod(frameIdx, visualizeEveryNFrames) == 0
            % Blase als Bereich einzeichnen
            rectangle(hAx, 'Position', [x_e, 2, len_px, imgH-4], ...
                'EdgeColor', 'c', 'LineWidth', 1.5, 'LineStyle', '--');
            plot(hAx, mid_x, imgH/2, 'c+', 'MarkerSize', 10, 'LineWidth', 2);
        end
    end

    if isempty(currentBubbleCentroids), prevBubbleCentroids = []; continue; end
    newPrevBubbleCentroids = [];

    % --- ID-Matching: Blasen zwischen Frames verknüpfen ---
    for c = 1:size(currentBubbleCentroids, 1)
        currX = currentBubbleCentroids(c, 1);
        assignedID = -1;

        if ~isempty(prevBubbleCentroids)
            % Blase wandert nach LINKS -> Alte X - Neue X > 0
            x_diffs = prevBubbleCentroids(:, 2) - currX;
            validMatches = find(x_diffs >= -2 & x_diffs < maxJumpDist_px);

            if ~isempty(validMatches)
                [~, bestMatchIdx] = min(x_diffs(validMatches));
                bestOldIdx = validMatches(bestMatchIdx);
                assignedID = prevBubbleCentroids(bestOldIdx, 1);
                prevBubbleCentroids(bestOldIdx, :) = [];
            end
        end

        if assignedID == -1
            assignedID = nextBubbleID;
            nextBubbleID = nextBubbleID + 1;
            bubbleTracker = [bubbleTracker; assignedID, frameIdx, currX, frameIdx, currX]; %#ok
        else
            trkIdx = find(bubbleTracker(:, 1) == assignedID);
            bubbleTracker(trkIdx, 4) = frameIdx;   % endFrame
            bubbleTracker(trkIdx, 5) = currX;       % endX

            % Track-Linie einzeichnen (Startposition → aktuell)
            if showVisuals && mod(frameIdx, visualizeEveryNFrames) == 0
                startX_hist = bubbleTracker(trkIdx, 3);
                plot(hAx, [startX_hist, currX], [imgH/2+15, imgH/2+15], 'g-', 'LineWidth', 2);
            end
        end

        if showVisuals && mod(frameIdx, visualizeEveryNFrames) == 0
            text(hAx, currX, imgH/2 - 15, sprintf('B%d', assignedID), ...
                'Color','y', 'FontWeight','bold', 'HorizontalAlignment','center');
        end

        newPrevBubbleCentroids = [newPrevBubbleCentroids; assignedID, currX]; %#ok
    end

    if showVisuals && mod(frameIdx, visualizeEveryNFrames) == 0
        hold(hAx, 'off'); drawnow;
    end

    prevBubbleCentroids = newPrevBubbleCentroids;
end

elapsedTime = toc(startTime);
fprintf('Tracking abgeschlossen in %.1f Sekunden.\n\n', elapsedTime);


%% ----------------- 4. Geschwindigkeiten Berechnen -----------------
validBubbles = 0;
res_speed_m_s = [];
res_dist_mm = [];

if ~isempty(bubbleTracker)
    for b = 1:size(bubbleTracker, 1)
        startFrame = bubbleTracker(b, 2);
        startX = bubbleTracker(b, 3);
        endFrame = bubbleTracker(b, 4);
        endX = bubbleTracker(b, 5);

        frameDiff = endFrame - startFrame;
        if frameDiff >= minFramesTracked
            % Distanz von rechts nach links (StartX > EndX) -> StartX - EndX für positive Werte
            dist_px = startX - endX; 
            
            if dist_px < 10 
                continue; % Ignoriere Fehl-Matches oder Rauschen
            end

            dist_mm = dist_px * px2mm;
            time_s = frameDiff * dt_frame;
            v_mm_s = dist_mm / time_s;
            v_m_s = v_mm_s / 1000;

            validBubbles = validBubbles + 1;
            res_speed_m_s(end+1, 1) = v_m_s; %#ok
            res_dist_mm(end+1, 1) = dist_mm; %#ok
        end
    end
end

if validBubbles > 0
    mean_speed = mean(res_speed_m_s);
    std_speed = std(res_speed_m_s);
    fprintf('--- ERGEBNISSE ---\n');
    fprintf('Gültige gemessene Blasen: %d\n', validBubbles);
    fprintf('Mittlere Geschwindigkeit: %.3f m/s\n', mean_speed);
    fprintf('Standardabweichung: %.3f m/s\n', std_speed);
    
    % Einfacher Plot der Geschwindigkeiten
    figure('Name', 'Geschwindigkeitsverteilung');
    histogram(res_speed_m_s, 10, 'FaceColor', 'b', 'EdgeColor', 'w');
    xlabel('Geschwindigkeit [m/s]');
    ylabel('Anzahl Blasen');
    title(sprintf('Mittlere Geschwindigkeit: %.3f m/s', mean_speed));
    grid on;
else
    fprintf('WARNUNG: Keine gültigen Blasen-Tracks für Geschwindigkeit gefunden.\n');
end
