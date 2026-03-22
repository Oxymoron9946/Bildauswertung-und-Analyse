%% Parallele Batch-Auswertung (Nur Geometrie & Längen)
clc; close all; clear;

batchRunID = now;
%% 1. Parameter & Konfiguration
% Filter für Flüssigkeits-Slugs
params.minPixel = 50;
params.minArea = 100;
params.minSolid = 0.50; 
params.maxSolid = 0.94;
params.minEcc = 0.05;
params.minAngle = 0; 
params.toleranceY = 0.1;
params.borderMargin = 2;

% Tracking Parameter
params.maxJumpDist_px = 50; 
params.minFramesTracked = 10; 

% Binning
params.binSize_mm = 2; 
params.fps = 200; % Fallback

% Füllen (Möglichkeit 2)
params.closeWidth = 3; 
params.closeHeight = 3; 
params.showBinarySteps = true; 

% Adaptive Threshold
params.sens = 0.7; 
params.neighborhoodSize = 51; 

%% 2. Batch-Parameter & Ordnerwahl
baseDir = uigetdir('', 'Bitte den Hauptordner (z.B. "Glaskanal") auswählen');
if baseDir == 0, return; end

allVideoFiles = dir(fullfile(baseDir, '**', 'XSM-3520 Camera 0330_*.avi'));
if isempty(allVideoFiles)
    error('Keine passenden .avi Dateien gefunden!');
end

% --- KALIBRIERUNGEN VORBEREITEN ---
calibMap = containers.Map('KeyType', 'char', 'ValueType', 'double');
fprintf('\n--- Lese Kalibrierungen ein ---\n');
calibVideoFiles = dir(fullfile(baseDir, '**', 'Kalibrierung_*', '*.avi'));
for c = 1:length(calibVideoFiles)
    cFolder = calibVideoFiles(c).folder;
    cName = calibVideoFiles(c).name;
    tok = regexp(cFolder, '(Pos_\d+_Kal_\d+)', 'tokens');
    if ~isempty(tok)
        groupName = tok{1}{1};
        vcalib = VideoReader(fullfile(cFolder, cName));
        firstFrameCalib = readFrame(vcalib);
        if ndims(firstFrameCalib) == 3
            firstFrameCalib = rgb2gray(firstFrameCalib);
        end
        [px2mm_calib, calibSuccess] = setup_Calibration(firstFrameCalib, false);
        if calibSuccess
            calibMap(groupName) = px2mm_calib;
            fprintf('Gruppe %s: %.5f mm/px\n', groupName, px2mm_calib);
        end
    end
end
fprintf('--------------------------------\n\n');

% Messvideos filtern
videoFiles = [];
for i = 1:length(allVideoFiles)
    if ~contains(allVideoFiles(i).folder, 'Kalibrierung_')
        videoFiles = [videoFiles; allVideoFiles(i)]; %#ok<AGROW>
    end
end

fprintf('Starte parallele Batch-Auswertung für %d Messvideos...\n', length(videoFiles));
resultsCell = cell(length(videoFiles), 1);
statsCell = cell(length(videoFiles), 1);

%% 3. Parallele Hauptschleife (parfor)
D = parallel.pool.DataQueue;
afterEach(D, @(~) fprintf('.')); 

parfor vIdx = 1:length(videoFiles)
    videoFile = fullfile(videoFiles(vIdx).folder, videoFiles(vIdx).name);
    groupTok = regexp(videoFile, '(Pos_\d+_Kal_\d+)', 'tokens');
    if isempty(groupTok)
        continue;
    end
    groupName = groupTok{1}{1};
    
    folders = strsplit(videoFiles(vIdx).folder, filesep);
    paramFolder = folders{end-1};
    
    paramTokens = regexp(paramFolder, '(?<gas>[\d,]+)_(?<liq>[\d,]+)_Pos_(?<pos>\d+)', 'names');
    if isempty(paramTokens)
        vGasStr = "NaN"; vLiqStr = "NaN"; posNum = NaN; 
    else
        vGasStr = string(paramTokens.gas);
        vLiqStr = string(paramTokens.liq);
        posNum = str2double(paramTokens.pos);
    end

    localParams = params;
    localParams.videoFile = videoFile;
    
    try
        v = VideoReader(localParams.videoFile);
        v.CurrentTime = 0;
        
        if isKey(calibMap, groupName)
            px2mm = calibMap(groupName);
        else
            error('Keine Kalibrierung vorhanden.');
        end
        
        % Absolute Position berechnen
        if posNum == 1
            localParams.kanalStart_mm = 0;
        elseif posNum == 2
            localParams.kanalStart_mm = 181.5 * 1.05;
        elseif posNum == 3
            localParams.kanalStart_mm = 415.5 * 1.05;
        else
            localParams.kanalStart_mm = 0;
        end
        
        imgH = v.Height; imgW = v.Width;
        roi = struct('y0', 1, 'y1', imgH, 'x0', 1, 'x1', imgW);
        
        bubbleTracker = []; 
        nextBubbleID = 1;
        prevBubbleCentroids = []; 
        channelHeightEstimate = NaN; 
        frameIdx = 0;
        
        while hasFrame(v)
            frameIdx = frameIdx + 1;
            I_full = readFrame(v);
            if ndims(I_full) == 3, I_full = rgb2gray(I_full); end
            I_roi = I_full(roi.y0:roi.y1, roi.x0:roi.x1);
            
            % HIER GEÄNDERT: detect_Bubbles liefert nun 5-spaltige Centroids (inkl UC)
            [currentBubbleCentroids, channelHeightEstimate, ~, ~] = ...
                detect_Bubbles(I_roi, channelHeightEstimate, localParams);
            
            [bubbleTracker, prevBubbleCentroids, nextBubbleID] = track_Bubbles(...
                currentBubbleCentroids, prevBubbleCentroids, bubbleTracker, nextBubbleID, frameIdx, localParams.maxJumpDist_px);
        end
        
        imgW = roi.x1 - roi.x0 + 1; 
        mean_UC_mm = NaN; % Wird im neuen evaluate_Physics nicht mehr global benötigt!
        
        % HIER GEÄNDERT: evaluate_Physics rechnet nun Blasen- & Sluglängen!
        [resultsTable, statsTable] = evaluate_Physics(bubbleTracker, px2mm, localParams.fps, ...
            localParams.minFramesTracked, imgW, localParams.kanalStart_mm, localParams.binSize_mm, mean_UC_mm);
        
        % Metadaten anhängen (NUR Gas, Liq, Pos -> P und T macht Python!)
        numRowsStats = height(statsTable);
        if numRowsStats > 0
            MetaDataStats = table(repmat(vGasStr, numRowsStats, 1), repmat(vLiqStr, numRowsStats, 1), ...
                             repmat(posNum, numRowsStats, 1), ...
                             'VariableNames', {'GasVelocity', 'LiquidVelocity', 'CameraPosition'});
            statsTable = [MetaDataStats, statsTable];
            statsTable.Properties.RowNames = {};
        end
        
        statsCell{vIdx} = statsTable;
        
    catch ME
        warning('Fehler bei Video %d: %s', vIdx, ME.message);
    end
    send(D, vIdx); 
end
fprintf('\n');

%% 4. Ergebnisse zusammenfassen und speichern
validStatsIdx = cellfun(@(x) ~isempty(x) && istable(x) && height(x) > 0, statsCell);
statsCell = statsCell(validStatsIdx);

if ~isempty(statsCell)
    MasterTableStats = vertcat(statsCell{:});
    writetable(MasterTableStats, fullfile(baseDir, 'Gesamtauswertung_Statistik.csv'), 'Delimiter', ';');
    fprintf('Gesamte Statistik gespeichert in Gesamtauswertung_Statistik.csv\n');
    
    % HIER GEÄNDERT: Neue Plotfunktion aufrufen
    plotsDir = fullfile(baseDir, 'Geschwindigkeits_Plots');
    generate_Batch_Plots(table(), MasterTableStats, plotsDir);
    fprintf('Batch-Auswertung erfolgreich beendet.\n');
else
    fprintf('Keine validen Daten zur Speicherung gefunden.\n');
end
