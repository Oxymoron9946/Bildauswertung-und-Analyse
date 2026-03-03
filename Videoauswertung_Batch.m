%% Parallele Batch-Videoauswertung von Blasenströmungen (Taylor-Flow)
clc; close all; clear;

%% ----------------- 1. Batch-Parameter & Ordnerwahl -----------------
minPixel = 50;
minArea  = 100;
minSolid = 0.50; 
maxSolid = 0.98;
minEcc   = 0.05;
minAngle = 0;         
toleranceY = 0.1;     
minHeightRatio = 0.22;
borderMargin = 2; 

% WICHTIG: Visualisierung MUSS im parfor-Modus false sein!
showVisuals = false;           

baseDir = uigetdir('', 'Bitte den Hauptordner (z.B. "Glaskanal") auswählen');
if baseDir == 0, return; end

allVideoFiles = dir(fullfile(baseDir, '**', 'XSM-3520 Camera 0330_*.avi'));
if isempty(allVideoFiles)
    error('Keine passenden .avi Dateien gefunden!');
end

% --- FILTERN DER DATEIEN (Ohne 500fps) ---
validFiles = [];
for i = 1:length(allVideoFiles)
    if ~contains(allVideoFiles(i).folder, '500fps')
        validFiles = [validFiles; allVideoFiles(i)]; %#ok<AGROW>
    end
end

if isempty(validFiles)
    error('Nach dem Filtern sind keine Dateien mehr übrig!');
end

% --- ALLE GÜLTIGEN DATEIEN AUSWERTEN ---
videoFiles = validFiles; % Keine Begrenzung mehr
fprintf('Starte parallele Batch-Auswertung für alle %d gefundenen Videos...\n', length(videoFiles));

% Cell Array zum koordinierten Speichern der Ergebnisse im Parallelbetrieb
resultsCell = cell(length(videoFiles), 1);

%% ----------------- 2. Parallele Hauptschleife (parfor) -----------------
% Startet den parallelen Pool (nutzt mehrere CPU-Kerne gleichzeitig)

% Vorbereitung für den Konsolen-Fortschritt
D = parallel.pool.DataQueue;
totalVideos = length(videoFiles);

% Ruft die lokale Funktion am Ende des Skripts auf
afterEach(D, @updateProgress); 

% Array für Statusmeldungen (statt fprintf in die Konsole)
statusMessages = cell(length(videoFiles), 1);


parfor vIdx = 1:length(videoFiles)
    % Automatische Kanalhöhen-Schätzung
    channelHeightEstimate = NaN;
    firstFrameAnalyzed = false;
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
    
    %% --- BILDVERARBEITUNG FÜR DAS AKTUELLE VIDEO ---
    v = VideoReader(videoFile);
    firstFrame = readFrame(v);
    if ndims(firstFrame) == 3, firstFrameGray = rgb2gray(firstFrame); else, firstFrameGray = firstFrame; end
    [imgH_full, imgW_full] = size(firstFrameGray); 

    % --- Automatische Kalibrierung ---
    px2mm = 1; 
    searchStartY = floor(imgH_full * 0.30);
    searchEndY   = floor(imgH_full * 0.60);
    searchArea = firstFrameGray(searchStartY:searchEndY, :);

    edgesV = edge(searchArea, 'sobel', 'vertical');
    rowSumV = sum(edgesV, 2);
    [~, bestY_local] = max(rowSumV); 
    bestY = bestY_local + searchStartY - 1;

    y_start = max(1, bestY - 40);
    y_end   = min(imgH_full, bestY + 5);
    x_margin = 25; 
    rulerBand = double(firstFrameGray(y_start:y_end, x_margin:end-x_margin));

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
        end
    end

    % --- Automatische ROI Erkennung ---
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
        padding = 10; 
        y0 = max(1, y_top - padding);
        y1 = min(imgH_full, y_bottom + padding);
        x0 = 1; x1 = imgW_full;
    else
        continue; % Überspringen, wenn keine ROI gefunden
    end

    % --- Frame Loop ---
    totalFrames = v.NumFrames;
    maxDetections = totalFrames * 35;  
    res_frame   = zeros(maxDetections, 1); 
    res_time_s  = zeros(maxDetections, 1); 
    res_posIdx  = zeros(maxDetections, 1); 
    res_len_px  = zeros(maxDetections, 1); 
    res_len_mm  = zeros(maxDetections, 1); 
    res_mid_x   = zeros(maxDetections, 1);
    
    dataIdx = 0;  
    frameIdx = 0;

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
        B = imfill(B, 'holes');
        B = bwareaopen(B, minPixel);
        
        [L, num] = bwlabel(B);
        if num < 2, continue; end
        
        statsBasic = regionprops(L, 'Area', 'BoundingBox');
        candidateIdx = find([statsBasic.Area] > minArea);
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
            if abs(cy_local - middle_Y) > (imgH * 0.20)
                continue; % Objekt liegt zu weit oben oder unten (Störstruktur)
            end

            if (sol >= minSolid && sol <= maxSolid && ecc >= minEcc && abs(ori) >= minAngle)
                
                bx0 = max(1, floor(bb(1))); by0 = max(1, floor(bb(2)));
                bx1 = min(imgW, ceil(bb(1)+bb(3)-1)); by1 = min(imgH, ceil(bb(2)+bb(4)-1));
                
                if bx0 <= borderMargin || bx1 >= (imgW - borderMargin), continue; end
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
                cBand = cP(inBand); rBand = rP(inBand);
                
                if isempty(cBand), continue; end
                leftMask = cBand < cx_local; rightMask = cBand >= cx_local;
                if ~any(leftMask) || ~any(rightMask), continue; end
                
                cL = cBand(leftMask); rL = rBand(leftMask);
                cR = cBand(rightMask); rR = rBand(rightMask);
                
                left_x_local = max(cL); right_x_local = min(cR);
                
                det(end+1) = struct('cx', statsFull(k).Centroid(1), 'cy', statsFull(k).Centroid(2), ...
                    'leftX', left_x_local+bx0-1, 'leftY', round(mean(rL(cL==left_x_local)))+by0-1, ...
                    'rightX', right_x_local+bx0-1, 'rightY', round(mean(rR(cR==right_x_local)))+by0-1, ...
                    'bb', [bx0 by0 (bx1-bx0+1) (by1-by0+1)]); %#ok<AGROW>
            end
        end
        [~, sIdx] = sort([det.cx], 'descend');
        det = det(sIdx); 
        nDet = numel(det);
        
        currentPosIdx = 1; 
        if nDet >= 2
            for j = 1:(nDet-1)
                bbLeft = det(j).bb; touchesLeft = bbLeft(1) <= borderMargin;
                bbRight = det(j+1).bb; touchesRight = (bbRight(1) + bbRight(3)) >= (imgW - borderMargin);
                
                if touchesLeft || touchesRight, continue; end
               
                x_s = det(j).leftX;      
                x_e = det(j+1).rightX; 
                len_px = x_s - x_e;       

                
                if len_px <= 0, continue; end
                
                len_mm = len_px * px2mm;
                mid_x = (x_e + x_s)/2;
                
                dataIdx = dataIdx + 1;
                res_frame(dataIdx)   = frameIdx;
                res_time_s(dataIdx)  = (frameIdx-1)/fps;
                res_posIdx(dataIdx)  = currentPosIdx;
                res_len_px(dataIdx)  = len_px;
                res_len_mm(dataIdx)  = len_mm; 
                res_mid_x(dataIdx)   = mid_x;
                
                currentPosIdx = currentPosIdx + 1; 
            end
        end
    end
    
    %% --- DATEN DIESES VIDEOS INS CELL-ARRAY SPEICHERN & PLOTTEN ---
    if dataIdx > 0
        TBL_local = table(res_frame(1:dataIdx), res_time_s(1:dataIdx), res_posIdx(1:dataIdx), ...
            res_len_px(1:dataIdx), res_len_mm(1:dataIdx), res_mid_x(1:dataIdx), ...
            'VariableNames', {'Frame','Time_s','BubbleIndex','Len_px','Len_mm','MidX'});
        
        numRows = height(TBL_local);
        TBL_local.GasVelocity = repmat(vGasStr, numRows, 1);
        TBL_local.LiquidVelocity = repmat(vLiqStr, numRows, 1);
        TBL_local.CameraPosition = repmat(posNum, numRows, 1);
        TBL_local.FPS = repmat(fps, numRows, 1);
        TBL_local.RecordNum = repmat(recNum, numRows, 1);
        
        resultsCell{vIdx} = TBL_local;
        
        % NEU: Nachricht speichern statt ausgeben
        statusMessages{vIdx} = sprintf('ERFOLG | Blasen gemessen: %d | Kanalhoehe geschätzt: %.1f px', dataIdx, channelHeightEstimate);
    else
        % NEU: Nachricht speichern statt ausgeben
        statusMessages{vIdx} = 'FEHLER | KEINE Blasen erkannt.';
    end
    
    send(D, vIdx); % Aktualisiert die Fortschrittsanzeige
end % <-- Ende der parfor Schleife


%% ----------------- 3. Finale Statistik, Plotten und Speichern -----------------
fprintf('\n======================================================\n');
fprintf('PARALLELE BATCH-VERARBEITUNG ABGESCHLOSSEN.\n');

% Cell Array zu einer großen Tabelle zusammenfügen
MasterTable_Raw = vertcat(resultsCell{:});

if isempty(MasterTable_Raw)
    error('Es konnten in keinem der Videos Daten erzeugt werden.');
end

% 1. Rohdaten speichern
rawSavePath = fullfile(baseDir, 'Gesamtauswertung_Rohdaten.csv');
writetable(MasterTable_Raw, rawSavePath);

%% ----------------- 4. Einzelne Diagramme pro Video erstellen -----------------
fprintf('\n--- Erstelle Einzeldiagramme für jedes Video ---\n');

% Eindeutige Video-Konstellationen finden
uniqueVideos = unique(MasterTable_Raw(:, {'GasVelocity', 'LiquidVelocity', 'CameraPosition', 'FPS', 'RecordNum'}));

% Für jede Konstellation ein eigenes Diagramm
for i = 1:height(uniqueVideos)
    gas = uniqueVideos.GasVelocity(i);
    liq = uniqueVideos.LiquidVelocity(i);
    pos = uniqueVideos.CameraPosition(i);
    fps_val = uniqueVideos.FPS(i);
    rec = uniqueVideos.RecordNum(i);
    
    % Daten für dieses spezifische Video filtern
    idx = (MasterTable_Raw.GasVelocity == gas) & ...
          (MasterTable_Raw.LiquidVelocity == liq) & ...
          (MasterTable_Raw.CameraPosition == pos) & ...
          (MasterTable_Raw.FPS == fps_val) & ...
          (MasterTable_Raw.RecordNum == rec);
    
    videoData = MasterTable_Raw(idx, :);
    
    if isempty(videoData)
        continue;
    end
    
    % Statistik pro BubbleIndex (Position im Bild) berechnen
    videoStats = grpstats(videoData, 'BubbleIndex', {'mean', 'std', 'numel'}, 'DataVars', 'Len_mm');
    
    % Plot erstellen
    hFig = figure('Name', sprintf('Video %d/%d', i, height(uniqueVideos)), 'Position', [100 100 900 600], 'Visible', 'off');
    
    % Fehlerbalken-Plot
    errorbar(videoStats.BubbleIndex, videoStats.mean_Len_mm, videoStats.std_Len_mm, ...
        '-s', 'LineWidth', 2, 'MarkerSize', 10, 'MarkerFaceColor', 'c', ...
        'MarkerEdgeColor', 'b', 'Color', 'b', 'CapSize', 10);
    
    xlabel('Slug-Position im Bild (1 = Eintritt ganz rechts)', 'FontSize', 12, 'FontWeight', 'bold');
    ylabel('Mittlere Blasenlänge [mm]', 'FontSize', 12, 'FontWeight', 'bold');
    
    titleStr = sprintf('Blasenlängen-Statistik\nGas: %s m/s | Liq: %s m/s | Kameraposition: %d | %d fps | Aufnahme: %s', ...
        gas, liq, pos, fps_val, rec);
    title(titleStr, 'FontSize', 13, 'FontWeight', 'bold');
    
    grid on;
    xticks(videoStats.BubbleIndex);
    
    % Info-Textbox
    totalBubbles = sum(videoStats.numel_Len_mm);
    overallMean = mean(videoStats.mean_Len_mm);
    overallStd = std(videoStats.mean_Len_mm);
    
    infoText = sprintf('Gesamt: %d Blasen\nØ Länge: %.3f mm\nStdAbw: %.3f mm', ...
        totalBubbles, overallMean, overallStd);
    
    annotation('textbox', [0.15 0.75 0.2 0.15], 'String', infoText, ...
        'FontSize', 10, 'EdgeColor', 'k', 'BackgroundColor', 'w', 'FitBoxToText', 'on');
    
       % --- NEU: Zentralen Ordner für alle Plots erstellen ---
    plotsDir = fullfile(baseDir, 'Auswertungs_Plots');
    if ~exist(plotsDir, 'dir')
        mkdir(plotsDir); % Ordner erstellen, falls er nicht existiert
    end

    % Speichern des Plots DIREKT IM NEUEN PLOT-ORDNER
    plotName = sprintf('Einzelauswertung_Gas%s_Liq%s_Pos%d_%dfps_Rec%s.png', ...
        strrep(char(gas), ',', '-'), strrep(char(liq), ',', '-'), pos, fps_val, rec);
        
    plotSavePath = fullfile(plotsDir, plotName);
    saveas(hFig, plotSavePath);
    
    fprintf('Plot %d/%d zentral gespeichert: %s\n', i, height(uniqueVideos), plotName);
    close(hFig);

end % Ende der Schleife für uniqueVideos


% 2. Statistik gruppieren
StatsTable = grpstats(MasterTable_Raw, {'GasVelocity', 'LiquidVelocity', 'CameraPosition'}, ...
    {'mean', 'std', 'numel'}, 'DataVars', 'Len_mm');

StatsTable.Properties.VariableNames{'mean_Len_mm'} = 'Mean_Bubble_Length_mm';
StatsTable.Properties.VariableNames{'std_Len_mm'} = 'StdDev_Bubble_Length_mm';
StatsTable.Properties.VariableNames{'numel_Len_mm'} = 'Measured_Bubbles_Count';

statsSavePath = fullfile(baseDir, 'Gesamtauswertung_Statistik.csv');
writetable(StatsTable, statsSavePath);
fprintf('Ergebnisse als CSV gespeichert.\n');

% 3. Plotten der Ergebnisse (Blasenlänge über Kameraposition)
figure('Name', 'Blasenlänge über Position', 'Position', [200 200 800 600]);
hold on;
grid on;

% Finde alle eindeutigen Konstellationen (Gas + Liq)
uniqueConfigs = unique(StatsTable(:, {'GasVelocity', 'LiquidVelocity'}));

% Für jede Konstellation eine eigene Linie plotten
for i = 1:height(uniqueConfigs)
    gas = uniqueConfigs.GasVelocity(i);
    liq = uniqueConfigs.LiquidVelocity(i);
    
    % Filtere StatsTable für diese Konstellation
    idx = (StatsTable.GasVelocity == gas) & (StatsTable.LiquidVelocity == liq);
    subStats = StatsTable(idx, :);
    
    % Sortiere nach Position, damit die Linie korrekt verläuft (Pos 1 -> 2 -> 3)
    subStats = sortrows(subStats, 'CameraPosition');
    
    displayName = sprintf('Gas: %s, Liq: %s', gas, liq);
    
    % Plot mit Errorbars (Standardabweichung)
    errorbar(subStats.CameraPosition, subStats.Mean_Bubble_Length_mm, subStats.StdDev_Bubble_Length_mm, ...
        '-o', 'LineWidth', 1.5, 'MarkerSize', 8, 'DisplayName', displayName);
end

xlabel('Kameraposition');
ylabel('Mittlere Blasenlänge [mm]');
title('Entwicklung der Blasenlänge entlang des Kanals');
xticks([1 2 3]); % Positionen fixieren
legend('Location', 'best');

%% ----------------- 5. Automatische Warnungen & Logdatei erstellen -----------------
fprintf('\n--- Erstelle Logdatei mit Auswertungsübersicht & Warnungen ---\n');

logFilePath = fullfile(baseDir, 'Auswertung_Uebersicht_und_Warnungen_Log.txt');
fileID = fopen(logFilePath, 'w');

fprintf(fileID, '======================================================\n');
fprintf(fileID, ' AUSWERTUNGS-LOG & WARNUNGEN \n');
fprintf(fileID, ' Datum: %s\n', datestr(now, 'dd.mm.yyyy HH:MM'));
fprintf(fileID, ' Strömungsrichtung: RECHTS -> LINKS\n');
fprintf(fileID, '======================================================\n\n');

for vIdx = 1:length(videoFiles)
    folders = strsplit(videoFiles(vIdx).folder, filesep);
    paramFolder = folders{end-1};
    fpsFolder = folders{end};
    
    paramTokens = regexp(paramFolder, '(?<gas>[\d,]+)_(?<liq>[\d,]+)_Position_(?<pos>\d+)', 'names');
    fpsTokens = regexp(fpsFolder, '(?<fps>\d+)fps_(?<rec>\d+)', 'names');
    
    if isempty(paramTokens) || isempty(fpsTokens)
        fprintf(fileID, '### Datei %d: %s\n', vIdx, videoFiles(vIdx).name);
        fprintf(fileID, '    STATUS: ÜBERSPRUNGEN (Falsches Ordnerformat)\n\n');
        continue;
    end
    
    gas = string(paramTokens.gas);
    liq = string(paramTokens.liq);
    pos = str2double(paramTokens.pos);
    fps_val = str2double(fpsTokens.fps);
    rec = string(fpsTokens.rec);
    
    % 1. Basis-Informationen & Konsolen-Status schreiben
    fprintf(fileID, '### Video %d: Gas: %s | Liq: %s | Pos: %d | %dfps | Rec: %s\n', ...
            vIdx, gas, liq, pos, fps_val, rec);
    fprintf(fileID, '    STATUS: %s\n', statusMessages{vIdx});
    
    % Daten für dieses spezifische Video filtern
    idx = (MasterTable_Raw.GasVelocity == gas) & (MasterTable_Raw.LiquidVelocity == liq) & ...
          (MasterTable_Raw.CameraPosition == pos) & (MasterTable_Raw.FPS == fps_val) & ...
          (MasterTable_Raw.RecordNum == rec);
          
    videoData = MasterTable_Raw(idx, :);
    
    % Falls keine Daten vorhanden sind (Warnung 1), direkt zur nächsten Datei
    if isempty(videoData)
        fprintf(fileID, '    -> [WARNUNG] Video enthält keine auswertbaren Daten!\n\n');
        continue;
    end
    
    videoStats = grpstats(videoData, 'BubbleIndex', {'mean'}, 'DataVars', 'Len_mm');
    lengths = videoStats.mean_Len_mm;
    
    % 2. Warnung: Ausreißer im Bild (Mitte größer als Rand) prüfen
    if height(videoStats) >= 3
        randEintritt = lengths(1);       % Eintritt rechts (Index 1)
        randAustritt = lengths(end);     % Austritt links (Letzter Index)
        mitteMax = max(lengths(2:end-1));
        
        if (mitteMax > randAustritt * 1.15) && (mitteMax > randEintritt * 1.15)
            fprintf(fileID, '    -> [HINWEIS] Ausreißer in der Bildmitte! Max Mitte: %.2f mm vs. Eintritt: %.2f mm, Austritt: %.2f mm\n', ...
                mitteMax, randEintritt, randAustritt);
        end
    end
    
    % 3. Warnung: Entwicklung über das Kamerabild (Strömung Rechts -> Links)
    if height(videoStats) >= 2
        startLen = lengths(1);     % Eintritt rechts = Start
        endLen = lengths(end);     % Austritt links = Ende
        
        diffPercent = ((endLen - startLen) / startLen) * 100;
        
        if diffPercent > 10
            fprintf(fileID, '    -> [WACHSTUM] Länge hat sich im Bild um +%.1f%% vergrößert (Von %.2f mm auf %.2f mm).\n', ...
                diffPercent, startLen, endLen);
        elseif diffPercent < -10
            fprintf(fileID, '    -> [SCHRUMPFUNG] Länge hat sich im Bild um %.1f%% verkleinert (Von %.2f mm auf %.2f mm).\n', ...
                diffPercent, startLen, endLen);
        elseif abs(diffPercent) <= 3
            fprintf(fileID, '    -> [KONSTANT] Länge blieb im Bild nahezu konstant (Änderung nur %.1f%%).\n', ...
                diffPercent);
        end
    end
    
    % Leerzeile für besseren Lesefluss zum nächsten Video
    fprintf(fileID, '\n');
end

fclose(fileID);
fprintf('Auswertung abgeschlossen. Logdatei gespeichert unter:\n%s\n', logFilePath);

%% ----------------- 6. Hilfsfunktionen -----------------
% Diese Funktion wird von der DataQueue aufgerufen, um den Fortschritt aufzuaddieren
function updateProgress(~)
    % 'persistent' sorgt dafür, dass die Variable zwischen den Aufrufen gespeichert bleibt
    persistent pCounter;
    if isempty(pCounter)
        pCounter = 1;
    else
        pCounter = pCounter + 1;
    end
    
    % Um die Gesamtzahl der Videos in dieser Hilfsfunktion zu kennen,
    % holen wir uns die Variable aus dem "Basis-Workspace".
    total = evalin('base', 'length(videoFiles)');
    
    fprintf('Fortschritt: %d / %d Videos abgeschlossen...\n', pCounter, total);
end
