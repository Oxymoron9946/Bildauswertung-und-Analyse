%% Parallele Batch-Auswertung (Gekoppelte Physik - Bereinigt)
clc; close all; clear;

%% 1. Parameter & Konfiguration (Ohne Visualisierungs-Overhead)
% Filter für Flüssigkeits-Slugs
params.minPixel   = 50;
params.minArea    = 100;
params.minSolid   = 0.50; 
params.maxSolid   = 0.98;
params.minEcc     = 0.05;
params.minAngle   = 0; 
params.toleranceY = 0.1;
params.borderMargin = 2;

% Tracking Parameter
params.maxJumpDist_px   = 50; 
params.minFramesTracked = 10; 

% Position und Binning
params.kanalStart_mm = 0; 
params.binSize_mm    = 3; 
params.fps           = 200; % Fallback, falls nicht aus dem Ordner extrahiert

%% 2. Batch-Parameter & Ordnerwahl
baseDir = uigetdir('', 'Bitte den Hauptordner (z.B. "Glaskanal") auswählen');
if baseDir == 0, return; end

% Alle passenden .avi-Dateien im Verzeichnis und Unterverzeichnissen suchen
allVideoFiles = dir(fullfile(baseDir, '**', 'XSM-3520 Camera 0330_*.avi'));
if isempty(allVideoFiles)
    error('Keine passenden .avi Dateien gefunden!');
end

% --- FILTERN DER DATEIEN (Nur alles außer 500fps) ---
validFiles = [];
for i = 1:length(allVideoFiles)
    if ~contains(allVideoFiles(i).folder, '500fps')
        validFiles = [validFiles; allVideoFiles(i)]; %#ok<AGROW>
    end
end

if isempty(validFiles)
    error('Nach dem Filtern sind keine Dateien mehr übrig!');
end

videoFiles = validFiles; 
fprintf('Starte parallele Batch-Auswertung für alle %d gefundenen Videos (ohne 500fps)...\n', length(videoFiles));

% Cell Arrays für Ergebnisse koordinieren (Parallelbetrieb)
resultsCell = cell(length(videoFiles), 1);
statsCell = cell(length(videoFiles), 1);

%% 3. Parallele Hauptschleife (parfor)
D = parallel.pool.DataQueue;
totalVideos = length(videoFiles);
afterEach(D, @updateProgress); 

parfor vIdx = 1:length(videoFiles)
    % --- Dateipfade und Metadaten ---
    videoFile = fullfile(videoFiles(vIdx).folder, videoFiles(vIdx).name);

    folders = strsplit(videoFiles(vIdx).folder, filesep);
    paramFolder = folders{end-1};
    fpsFolder = folders{end};

    paramTokens = regexp(paramFolder, '(?<gas>[\d,]+)_(?<liq>[\d,]+)_Position_(?<pos>\d+)', 'names');
    fpsTokens = regexp(fpsFolder, '(?<fps>\d+)fps_(?<rec>\d+)', 'names');

    if isempty(paramTokens) || isempty(fpsTokens)
        vGasStr = "NaN"; vLiqStr = "NaN"; posNum = NaN; fps_val = params.fps; recNum = "NaN";
    else
        vGasStr = string(paramTokens.gas);
        vLiqStr = string(paramTokens.liq);
        posNum = str2double(paramTokens.pos);
        fps_val = str2double(fpsTokens.fps);
        recNum = string(fpsTokens.rec);
    end

    % Lokale Kopie der Parameter für parfor
    localParams = params;
    localParams.videoFile = videoFile;
    localParams.fps = fps_val; 

    try
        % --- Video initialisieren & Setup ---
        v = VideoReader(localParams.videoFile);
        firstFrame = readFrame(v);
        v.CurrentTime = 0;

        if ndims(firstFrame) == 3, firstFrameGray = rgb2gray(firstFrame); 
        else, firstFrameGray = firstFrame; end

        % Kalibrierung (hartkodiert: keine Visualisierung -> false)
        [px2mm, roi, calibSuccess] = setup_Calibration(firstFrameGray, false);

        if ~calibSuccess
            px2mm = 1; % Fallback
        end

        % --- Tracking Schleife ---
        bubbleTracker = []; 
        nextBubbleID = 1;
        prevBubbleCentroids = []; 
        channelHeightEstimate = NaN; 
        collected_UC_mm = []; 
        frameIdx = 0;

        while hasFrame(v)
            frameIdx = frameIdx + 1;
            I_full = readFrame(v);
            if ndims(I_full) == 3, I_full = rgb2gray(I_full); end

            % ROI ausschneiden
            I_roi = I_full(roi.y0:roi.y1, roi.x0:roi.x1);

            % Blasen detektieren
            [currentBubbleCentroids, channelHeightEstimate, det, currentUC_px] = ...
                detect_Bubbles(I_roi, channelHeightEstimate, localParams);

            if ~isempty(currentUC_px)
                collected_UC_mm = [collected_UC_mm; currentUC_px * px2mm]; %#ok<AGROW>
            end

            % Tracking
            [bubbleTracker, prevBubbleCentroids, nextBubbleID] = track_Bubbles(...
                currentBubbleCentroids, prevBubbleCentroids, bubbleTracker, nextBubbleID, frameIdx, localParams.maxJumpDist_px);
        end

        % --- Auswertung der gekoppelten Physik ---
        imgW = roi.x1 - roi.x0 + 1; 
        if isempty(collected_UC_mm), mean_UC_mm = NaN; else, mean_UC_mm = mean(collected_UC_mm); end

        [resultsTable, statsTable] = evaluate_Physics(bubbleTracker, px2mm, localParams.fps, ...
            localParams.minFramesTracked, imgW, localParams.kanalStart_mm, localParams.binSize_mm, mean_UC_mm);

        % --- Metadaten anhängen ---
        numRowsRes = height(resultsTable);
        if numRowsRes > 0
            MetaData = table(repmat(vGasStr, numRowsRes, 1), repmat(vLiqStr, numRowsRes, 1), ...
                             repmat(posNum, numRowsRes, 1), repmat(fps_val, numRowsRes, 1), ...
                             repmat(recNum, numRowsRes, 1), ...
                             'VariableNames', {'GasVelocity', 'LiquidVelocity', 'CameraPosition', 'FPS', 'RecordNum'});
            resultsTable = [MetaData, resultsTable];
        end

        numRowsStats = height(statsTable);
        if numRowsStats > 0
            MetaDataStats = table(repmat(vGasStr, numRowsStats, 1), repmat(vLiqStr, numRowsStats, 1), ...
                             repmat(posNum, numRowsStats, 1), repmat(fps_val, numRowsStats, 1), ...
                             repmat(recNum, numRowsStats, 1), ...
                             'VariableNames', {'GasVelocity', 'LiquidVelocity', 'CameraPosition', 'FPS', 'RecordNum'});
            statsTable = [MetaDataStats, statsTable];
        end

        % --- Speichern der Teilergebnisse ---
        resultsCell{vIdx} = resultsTable;
        statsCell{vIdx} = statsTable;

    catch ME
        warning('Fehler bei Video %d (%s): %s', vIdx, videoFile, ME.message);
    end

    % Fortschritt aktualisieren
    send(D, vIdx); 
end

%% 4. Ergebnisse zusammenfassen und speichern
fprintf('\n--- Fasse Daten zusammen ---\n');

% Leere Einträge (z.B. wegen Fehlern) entfernen
resultsCell = resultsCell(~cellfun('isempty', resultsCell));
statsCell = statsCell(~cellfun('isempty', statsCell));

if ~isempty(resultsCell)
    MasterTable_Results = vertcat(resultsCell{:});
    writetable(MasterTable_Results, fullfile(baseDir, 'Gesamtauswertung_Ergebnisse.csv'));
    fprintf('Gesamte Ergebnisse gespeichert in: Gesamtauswertung_Ergebnisse.csv\n');
end

if ~isempty(statsCell)
    MasterTable_Stats = vertcat(statsCell{:});
    writetable(MasterTable_Stats, fullfile(baseDir, 'Gesamtauswertung_Statistik.csv'));
    fprintf('Gesamte Statistik gespeichert in: Gesamtauswertung_Statistik.csv\n');
end

fprintf('Batch-Auswertung erfolgreich beendet.\n');

%% Hilfsfunktion für den Konsolen-Fortschritt (DataQueue)
function updateProgress(~)
    persistent pCounter;
    if isempty(pCounter)
        pCounter = 1;
    else
        pCounter = pCounter + 1;
    end
    total = evalin('base', 'length(videoFiles)');
    fprintf('Fortschritt: %d / %d Videos abgeschlossen...\n', pCounter, total);
end
