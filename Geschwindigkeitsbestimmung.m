%% Batch-Videoauswertung - GESCHWINDIGKEITS-MESSUNG (Nur 500fps Videos)
clc; close all; clear;

%% ----------------- 1. Batch-Parameter & Ordnerwahl -----------------
% Filter für Flüssigkeits-Slugs (identisch zum Längen-Skript)
minPixel = 50;
minArea  = 100;
minSolid = 0.50; 
maxSolid = 0.98;
minEcc   = 0.05;
minAngle = 0;         
toleranceY = 0.1;     
minHeightRatio = 0.22; 
borderMargin = 2; 

% Tracking Parameter
maxJumpDist_px = 150; % Maximale Pixel, die eine Blase in 1 Frame springen darf

baseDir = uigetdir('', 'Bitte den Hauptordner (z.B. "Glaskanal") auswählen');
if baseDir == 0, return; end

allVideoFiles = dir(fullfile(baseDir, '**', 'XSM-3520 Camera 0330_*.avi'));
if isempty(allVideoFiles)
    error('Keine passenden .avi Dateien gefunden!');
end

% --- FILTERN DER DATEIEN (NUR 500fps) ---
validFiles = [];
for i = 1:length(allVideoFiles)
    if contains(allVideoFiles(i).folder, '500fps')
        validFiles = [validFiles; allVideoFiles(i)]; %#ok<AGROW>
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
    searchEndY   = floor(imgH_full * 0.60);
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
        y0 = max(1, min(y_lines) + lowerThirdStartY - 1 - 15);
        y1 = min(imgH_full, max(y_lines) + lowerThirdStartY - 1 + 15);
        x0 = 1; x1 = imgW_full;
    else
        continue;
    end

    %% --- TRACKING LOGIK FÜR GESCHWINDIGKEIT ---
    v.CurrentTime = 0;
    
    % Tracking Historie
    % Format: [ID, startFrame, start_X_px, endFrame, end_X_px]
    bubbleTracker = []; 
    nextBubbleID = 1;
    prevCentroids = []; % Speichert [ID, X-Koordinate] des vorherigen Frames
    
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
        if num < 1, prevCentroids = []; continue; end
        
        statsBasic = regionprops(L, 'Area', 'BoundingBox');
        candidateIdx = find([statsBasic.Area] > minArea);
        if isempty(candidateIdx), prevCentroids = []; continue; end
        
        statsFull = regionprops(L, 'Solidity', 'Eccentricity', 'Orientation', 'Centroid');
        
        % Sammeln aller aktuellen X-Schwerpunkte der gefundenen Slugs
        currentCentroids = []; 
        
        for k = candidateIdx
            bb = statsBasic(k).BoundingBox;
            if bb(4) < (imgH * minHeightRatio), continue; end
            
            % Y-Zentrums-Filter (Milchglas-Rauschen blockieren)
            cy_local = statsFull(k).Centroid(2); 
            if abs(cy_local - (imgH/2)) > (imgH * 0.20), continue; end
            
            sol = statsFull(k).Solidity; ecc = statsFull(k).Eccentricity; ori = statsFull(k).Orientation;
            
            if (sol >= minSolid && sol <= maxSolid && ecc >= minEcc && abs(ori) >= minAngle)
                cx_local = statsFull(k).Centroid(1);
                
                % Blasen zu nah am Rand überspringen (unsichere Schwerpunkte)
                if cx_local < 20 || cx_local > (imgW - 20)
                    continue;
                end
                currentCentroids = [currentCentroids; cx_local]; %#ok<AGROW>
            end
        end
        
        % Sortieren von links nach rechts
        currentCentroids = sort(currentCentroids);
        newPrevCentroids = [];
        
        % ID-Zuweisung durch Frame-zu-Frame Vergleich
        for c = 1:length(currentCentroids)
            currX = currentCentroids(c);
            assignedID = -1;
            
            % Versuche, diese Blase mit einer aus dem vorherigen Frame zu matchen
            if ~isempty(prevCentroids)
                % Strömungsrichtung: Blase wandert nach LINKS (X wird kleiner)
                % Differenz: Alte Position (X) minus Aktuelle Position (X)
                % Muss positiv sein, da alte Position weiter rechts (größer) war
                x_diffs = prevCentroids(:, 2) - currX; 
                
                % Finde gültige Kandidaten (Blase hat sich nach links bewegt, aber nicht weiter als maxJumpDist)
                validMatches = find(x_diffs >= 0 & x_diffs < maxJumpDist_px);
                
                if ~isempty(validMatches)
                    % Nimm den besten Match (kleinster Abstand)
                    [~, bestMatchIdx] = min(x_diffs(validMatches));
                    bestOldIdx = validMatches(bestMatchIdx);
                    
                    assignedID = prevCentroids(bestOldIdx, 1);
                    
                    % Alten Eintrag löschen, damit er nicht doppelt zugewiesen wird
                    prevCentroids(bestOldIdx, :) = [];
                end
            end
            
            % Wenn kein Match gefunden -> Neue Blase, neue ID!
            if assignedID == -1
                assignedID = nextBubbleID;
                nextBubbleID = nextBubbleID + 1;
                
                % Neuen Eintrag im Tracker anlegen: [ID, startFrame, startX, endFrame, endX]
                bubbleTracker = [bubbleTracker; assignedID, frameIdx, currX, frameIdx, currX]; %#ok<AGROW>
            else
                % Vorhandene Blase aktualisieren (endFrame und endX überschreiben)
                trkIdx = find(bubbleTracker(:, 1) == assignedID);
                bubbleTracker(trkIdx, 4) = frameIdx;
                bubbleTracker(trkIdx, 5) = currX;
            end
            
            newPrevCentroids = [newPrevCentroids; assignedID, currX]; %#ok<AGROW>
        end
        
        prevCentroids = newPrevCentroids;
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
            
            % Eine Blase muss mindestens 10 Frames verfolgt worden sein, um gültig zu sein
            frameDiff = endFrame - startFrame;
            if frameDiff >= 10
                dist_px = endX - startX;
                dist_mm = dist_px * px2mm;
                time_s = frameDiff * dt_frame;
                
                v_mm_s = dist_mm / time_s;
                v_m_s = v_mm_s / 1000;
                
                validBubbles = validBubbles + 1;
                res_speed_mm_s(end+1, 1) = v_mm_s; %#ok<AGROW>
                res_speed_m_s(end+1, 1) = v_m_s; %#ok<AGROW>
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
    {'mean', 'std', 'numel'}, 'DataVars', 'Speed_m_s');

StatsTable.Properties.VariableNames{'mean_Speed_m_s'} = 'Mean_Velocity_m_s';
StatsTable.Properties.VariableNames{'std_Speed_m_s'} = 'StdDev_Velocity_m_s';
StatsTable.Properties.VariableNames{'numel_Speed_m_s'} = 'Measured_Bubbles_Count';

statsSavePath = fullfile(baseDir, 'Geschwindigkeit_Statistik.csv');
writetable(StatsTable, statsSavePath);

fprintf('Ergebnisse als "Geschwindigkeit_Statistik.csv" gespeichert.\n');
