%% Batch-Videoauswertung - GESCHWINDIGKEITS-MESSUNG (Nur 500fps Videos)
clc; close all; clear;

%% ----------------- 1. Batch-Parameter & Ordnerwahl -----------------
% Filter für Flüssigkeits-Slugs (identisch zum Längen-Skript)
minPixel = 50;
minArea = 100;
minSolid = 0.50; 
maxSolid = 0.98;
minEcc = 0.05;
minAngle = 0; 
toleranceY = 0.1; 
minHeightRatio = 0.22; 
borderMargin = 2; 

% Tracking Parameter
maxJumpDist_px = 50; % Maximale Pixel, die eine Blase in 1 Frame nach links springen darf
minFramesTracked = 10; % Eine Blase muss min. 10 Frames verfolgt werden für gültige Geschwindigkeit

baseDir = uigetdir('', 'Bitte den Hauptordner (z.B. "Glaskanal") auswählen');
if baseDir == 0, return; end

allVideoFiles = dir(fullfile(baseDir, '**', 'XSM-3520 Camera 0330_*.avi'));
if isempty(allVideoFiles)
    error('Keine passenden .avi Dateien gefunden!');
end

% --- FILTERN DER DATEIEN (NUR 500fps) ---
validFiles = [];
for i = 1:length(allVideoFiles)
    if ~contains(allVideoFiles(i).folder, '500fps')
        validFiles = [validFiles; allVideoFiles(i)]; %#ok
    end
end

if isempty(validFiles)
    error('Keine 500fps Dateien gefunden!');
end

videoFiles = validFiles; 
fprintf('Starte Geschwindigkeits-Messung für %d (500fps) Videos...\n\n', length(videoFiles));

resultsCell = cell(length(videoFiles), 1);

%% ----------------- 2. Parallele Hauptschleife (parfor) -----------------
parfor vIdx = 1:length(videoFiles)
    
    videoFile = fullfile(videoFiles(vIdx).folder, videoFiles(vIdx).name);
    
    folders = strsplit(videoFiles(vIdx).folder, filesep);
    paramFolder = folders{end-1};
    fpsFolder = folders{end};
    
    paramTokens = regexp(paramFolder, '(?<gas>[\d,]+)_(?<liq>[\d,]+)_Position_(?<pos>\d+)', 'names');
    fpsTokens = regexp(fpsFolder, '(?<fps>\d+)fps_(?<rec>\d+)', 'names');
    
    if isempty(paramTokens) || isempty(fpsTokens)
        fprintf('Datei %d übersprungen (Falsches Ordnerformat).\n', vIdx);
        continue;
    end
    
    vGasStr = string(paramTokens.gas);
    vLiqStr = string(paramTokens.liq);
    posNum = str2double(paramTokens.pos);
    fps = str2double(fpsTokens.fps);
    recNum = string(fpsTokens.rec);

    % Physik-Zeit
    dt_frame = 1 / fps; % Sekunden pro Frame (bei 500fps = 0.002s)

    %% --- BILD VORBEREITEN & ROI ---
    v = VideoReader(videoFile);
    firstFrame = readFrame(v);
    if ndims(firstFrame) == 3, firstFrameGray = rgb2gray(firstFrame); else, firstFrameGray = firstFrame; end
    [imgH_full, imgW_full] = size(firstFrameGray); 
    
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
            calibDistance_px = locs(longestChainIdx(end)+1) - locs(longestChainIdx(1));
            px2mm = calibDistance_mm / calibDistance_px;
        end
    end
    
    % --- ROI ---
    lowerThirdStartY = floor(imgH_full * 2/3);
    lowerThirdImg = firstFrameGray(lowerThirdStartY:end, :);
    edgesH = edge(lowerThirdImg, 'sobel', 'horizontal');
    edgesH(1:10, :) = 0; edgesH(end-9:end, :) = 0; edgesH(:, 1:10) = 0; edgesH(:, end-9:end) = 0;
    rowSum = sum(edgesH, 2);
    [~, locs_roi] = findpeaks(rowSum, 'MinPeakDistance', 20, 'SortStr', 'descend');
    
    if length(locs_roi) >= 2
        y_lines = locs_roi(1:2);
        y_top = min(y_lines) + lowerThirdStartY - 1;
        y_bottom = max(y_lines) + lowerThirdStartY - 1;
        
        % --- KORREKTUR DER KANTEN (Asymmetrisch aus Längen-Skript) ---
        y_top_corrected = y_top - 7; 
        y_bottom_corrected = y_bottom + 0; 
        
        padding = 8; 
        y0 = max(1, y_top_corrected - padding);
        y1 = min(imgH_full, y_bottom_corrected + padding);
        x0 = 1; x1 = imgW_full;
    else
        continue;
    end

    %% --- TRACKING LOGIK FÜR GESCHWINDIGKEIT ---
    v.CurrentTime = 0;
    
    % Tracking Historie: [ID, startFrame, start_midX_px, endFrame, end_midX_px]
    bubbleTracker = []; 
    nextBubbleID = 1;
    prevBubbleCentroids = []; % [ID, midX]
    
    % Kanalhöhen-Schätzung (identisch zur Längenauswertung)
    channelHeightEstimate = NaN;
    firstFrameAnalyzed = false;

    while hasFrame(v)
        frameIdx = round(v.CurrentTime * v.FrameRate) + 1; % Robusterer Frame-Zähler
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
        currentBubbleCentroids = []; % [midX, len_px]
    
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
            end
    
            newPrevBubbleCentroids = [newPrevBubbleCentroids; assignedID, currX]; %#ok
        end
    
        prevBubbleCentroids = newPrevBubbleCentroids;
    end

    %% --- GESCHWINDIGKEITEN BERECHNEN ---
    validBubbles = 0;
    res_speed_mm_s = [];
    res_speed_m_s = [];
    
    if ~isempty(bubbleTracker)
        for b = 1:size(bubbleTracker, 1)
            startFrame = bubbleTracker(b, 2);
            startX = bubbleTracker(b, 3);
            endFrame = bubbleTracker(b, 4);
            endX = bubbleTracker(b, 5);
            
            frameDiff = endFrame - startFrame;
            if frameDiff >= minFramesTracked
                % KORREKTUR: StartX ist weiter rechts (größer) als EndX (kleiner, weil links)
                % Um eine positive Strecke zu erhalten: StartX - EndX
                dist_px = startX - endX; 
                
                % Zusätzlicher Filter: Ignoriere Blasen, die sich kaum/garnicht bewegt haben 
                % (verhindert ID-Tauscher oder Rand-Artefakte)
                if dist_px < 10 
                    continue; 
                end

                dist_mm = dist_px * px2mm;
                time_s = frameDiff * dt_frame;
                
                v_mm_s = dist_mm / time_s;
                v_m_s = v_mm_s / 1000;
                
                validBubbles = validBubbles + 1;
                res_speed_mm_s(end+1, 1) = v_mm_s; %#ok
                res_speed_m_s(end+1, 1) = v_m_s; %#ok
            end
        end
    end
    
    if validBubbles > 0
        TBL_local = table(res_speed_mm_s, res_speed_m_s, ...
                          'VariableNames', {'Speed_mm_s', 'Speed_m_s'});
        
        TBL_local.GasVelocity = repmat(vGasStr, validBubbles, 1);
        TBL_local.LiquidVelocity = repmat(vLiqStr, validBubbles, 1);
        TBL_local.CameraPosition = repmat(posNum, validBubbles, 1);
        TBL_local.FPS = repmat(fps, validBubbles, 1);
        TBL_local.RecordNum = repmat(recNum, validBubbles, 1);

        TBL_local.Calibration_mm_px = repmat(px2mm, validBubbles, 1);
        
        resultsCell{vIdx} = TBL_local;
        fprintf('[%s \\ %s] fertig: Geschwindigkeit von %d Blasen gemessen (Mittelwert: %.2f m/s).\n', ...
                paramFolder, fpsFolder, validBubbles, mean(res_speed_m_s));
    else
        fprintf('[%s \\ %s] fertig: KEINE gültigen Blasen-Tracks gefunden.\n', paramFolder, fpsFolder);
    end
end

%% ----------------- 3. Finale Statistik und Speichern -----------------
fprintf('\n======================================================\n');
fprintf('GESCHWINDIGKEITS-MESSUNG ABGESCHLOSSEN.\n');

MasterTable_Speed = vertcat(resultsCell{:});

if isempty(MasterTable_Speed)
    error('Es konnten keine Geschwindigkeitsdaten erzeugt werden.');
end

% 1. Rohdaten speichern
rawSavePath = fullfile(baseDir, 'Geschwindigkeit_Rohdaten.csv');
writetable(MasterTable_Speed, rawSavePath);

% 2. Statistik gruppieren
StatsTable = grpstats(MasterTable_Speed, {'GasVelocity', 'LiquidVelocity', 'CameraPosition'}, ...
                      {'mean', 'std', 'numel'}, 'DataVars', {'Speed_m_s', 'Calibration_mm_px'});

% Spaltennamen bereinigen
StatsTable.Properties.VariableNames{'mean_Speed_m_s'} = 'Mean_Velocity_m_s';
StatsTable.Properties.VariableNames{'std_Speed_m_s'} = 'StdDev_Velocity_m_s';
StatsTable.Properties.VariableNames{'numel_Speed_m_s'} = 'Measured_Bubbles_Count';

% Den gemittelten Kalibrierfaktor übernehmen (std ist hier meist 0, kann gelöscht werden)
StatsTable.Properties.VariableNames{'mean_Calibration_mm_px'} = 'Calibration_mm_px';
StatsTable = removevars(StatsTable, {'std_Calibration_mm_px', 'numel_Calibration_mm_px'});

statsSavePath = fullfile(baseDir, 'Geschwindigkeit_Statistik.csv');
writetable(StatsTable, statsSavePath);

fprintf('Ergebnisse als "Geschwindigkeit_Statistik.csv" gespeichert.\n');

% 2. Statistik gruppieren
StatsTable = grpstats(MasterTable_Speed, {'GasVelocity', 'LiquidVelocity', 'CameraPosition'}, ...
                      {'mean', 'std', 'numel'}, 'DataVars', {'Speed_m_s', 'Calibration_mm_px'});

% Spaltennamen bereinigen
StatsTable.Properties.VariableNames{'mean_Speed_m_s'} = 'Mean_Velocity_m_s';
StatsTable.Properties.VariableNames{'std_Speed_m_s'} = 'StdDev_Velocity_m_s';
StatsTable.Properties.VariableNames{'numel_Speed_m_s'} = 'Measured_Bubbles_Count';

StatsTable.Properties.VariableNames{'mean_Calibration_mm_px'} = 'Calibration_mm_px';
StatsTable = removevars(StatsTable, {'std_Calibration_mm_px', 'numel_Calibration_mm_px'});

% Extrahiere die nominellen Geschwindigkeiten
nomGas = str2double(strrep(StatsTable.GasVelocity, ',', '.'));
nomLiq = str2double(strrep(StatsTable.LiquidVelocity, ',', '.'));

% Zweiphasen-Leerrohrgeschwindigkeit und Liq-Geschwindigkeit
StatsTable.Nominal_TP_Velocity_m_s = nomGas + nomLiq;
StatsTable.Nominal_Liq_Velocity_m_s = nomLiq;

% Abweichung: Gemessen / Eingestellt
StatsTable.Slip_Ratio = StatsTable.Mean_Velocity_m_s ./ StatsTable.Nominal_TP_Velocity_m_s;

% Ordner für die Plots erstellen
plotsDir = fullfile(baseDir, 'Geschwindigkeits_Plots');
if ~exist(plotsDir, 'dir')
    mkdir(plotsDir); 
end

%% ----------------- 4. Diagramme: Abweichung vs. u_TP (Separiert nach u_Liq) -----------------
fprintf('\n--- Erstelle Abweichungs-Diagramme pro Flüssigkeitsgeschwindigkeit ---\n');

uniqueLiqVals = unique(StatsTable.Nominal_Liq_Velocity_m_s);
uniquePositions = unique(StatsTable.CameraPosition);
colors = lines(length(uniquePositions));
markerStyles = {'o', 's', '^', 'd'};

for l = 1:length(uniqueLiqVals)
    currentLiq = uniqueLiqVals(l);
    
    % Filtere Tabelle auf die aktuelle Flüssigkeitsgeschwindigkeit
    idxLiq = (StatsTable.Nominal_Liq_Velocity_m_s == currentLiq);
    liqData = StatsTable(idxLiq, :);
    
    if isempty(liqData)
        continue;
    end
    
    hFig = figure('Name', sprintf('Abweichung bei u_Liq = %.3f', currentLiq), 'Position', [100 100 850 650]);
    hold on; grid on;
    
    % 1. Hell hervorgehobene x=y Ideal-Linie zeichnen
    maxVal = max([liqData.Nominal_TP_Velocity_m_s; liqData.Mean_Velocity_m_s]) * 1.1;
    minVal = min([liqData.Nominal_TP_Velocity_m_s; liqData.Mean_Velocity_m_s]) * 0.9;
    if minVal == 0, minVal = 0; end
    
    plot([0, maxVal], [0, maxVal], '-', 'Color', [0.7 0.7 0.7], 'LineWidth', 3, ...
        'DisplayName', 'Ideal (u_B = u_{TP})');
    
    % 2. Daten für jede Kameraposition bei dieser Liq-Geschwindigkeit plotten
    for p = 1:length(uniquePositions)
        pos = uniquePositions(p);
        
        idxPos = (liqData.CameraPosition == pos);
        posData = liqData(idxPos, :);
        
        if isempty(posData)
            continue;
        end
        
        % Nach u_TP sortieren für sauberen Linienverlauf
        posData = sortrows(posData, 'Nominal_TP_Velocity_m_s');
        
        errorbar(posData.Nominal_TP_Velocity_m_s, posData.Mean_Velocity_m_s, posData.StdDev_Velocity_m_s, ...
            ['-', markerStyles{mod(p-1, length(markerStyles))+1}], ...
            'LineWidth', 1.5, 'MarkerSize', 8, 'Color', colors(p,:), 'MarkerFaceColor', colors(p,:), ...
            'DisplayName', sprintf('Position %d', pos));
    end
    
    xlabel('Eingestellte Zweiphasengeschwindigkeit u_{TP} [m/s]', 'FontSize', 12, 'FontWeight', 'bold');
    ylabel('Gemessene Blasengeschwindigkeit u_B [m/s]', 'FontSize', 12, 'FontWeight', 'bold');
    title(sprintf('Geschwindigkeits-Abweichung bei konstanter u_{Liq} = %.3f m/s', currentLiq), 'FontSize', 14);
    
    legend('Location', 'northwest', 'FontSize', 11);
    xlim([minVal maxVal]);
    ylim([minVal maxVal]);
    
    % Speichern
    plotName = sprintf('Geschw_Abweichung_uLiq_%s.png', strrep(num2str(currentLiq), '.', '-'));
    saveas(hFig, fullfile(plotsDir, plotName));
    fprintf('Plot gespeichert: %s\n', plotName);
end

%% ----------------- 5. Plot: Kalibrierfaktor über alle Videos -----------------
fprintf('--- Erstelle Plot für Kalibrierfaktor vs. u_TP ---\n');

hFigCalib = figure('Name', 'Kalibrierfaktoren', 'Position', [150 150 800 500]);
hold on; grid on;

for p = 1:length(uniquePositions)
    pos = uniquePositions(p);
    idx = (StatsTable.CameraPosition == pos);
    posData = StatsTable(idx, :);
    
    if isempty(posData), continue; end
    
    posData = sortrows(posData, 'Nominal_TP_Velocity_m_s');
    
    plot(posData.Nominal_TP_Velocity_m_s, posData.Calibration_mm_px, ...
         ['-', markerStyles{mod(p-1, length(markerStyles))+1}], ...
         'LineWidth', 1.5, 'MarkerSize', 8, ...
         'Color', colors(p,:), 'MarkerFaceColor', colors(p,:), ...
         'DisplayName', sprintf('Position %d', pos));
end

globalMeanCalib = mean(StatsTable.Calibration_mm_px);
yline(globalMeanCalib, 'r--', 'LineWidth', 2, ...
    'DisplayName', sprintf('Ø Gesamt = %.5f mm/px', globalMeanCalib));

xlabel('Eingestellte Zweiphasengeschwindigkeit u_{TP} [m/s]', 'FontSize', 12, 'FontWeight', 'bold');
ylabel('Kalibrierfaktor [mm / px]', 'FontSize', 12, 'FontWeight', 'bold');
title('Stabilität der automatischen Bild-Kalibrierung', 'FontSize', 14);

yMin = min(StatsTable.Calibration_mm_px) * 0.95;
yMax = max(StatsTable.Calibration_mm_px) * 1.05;
if yMin < yMax
    ylim([yMin yMax]);
end

legend('Location', 'best', 'FontSize', 11);

plotCalibName = 'Übersicht_Kalibrierfaktoren_vs_uTP.png';
saveas(hFigCalib, fullfile(plotsDir, plotCalibName));
fprintf('Kalibrier-Plot gespeichert: %s\n', plotCalibName);

% Finale Statistik speichern
statsSavePath = fullfile(baseDir, 'Geschwindigkeit_Statistik.csv');
writetable(StatsTable, statsSavePath);
fprintf('\nErgebnisse als "Geschwindigkeit_Statistik.csv" gespeichert.\n');
