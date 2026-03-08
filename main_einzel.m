%% Hauptskript: Gekoppelte Volumen- und Geschwindigkeitsmessung
clc; close all; clear;

%% 1. Parameter & Konfiguration
params.videoFile = 'Test\test_14.avi';
params.fps = 200; % Entsprechend der Kamera-Einstellung

% Visualisierung
params.showCalibrationImage  = false;
params.showVisuals           = false; % Live-Tracking an/aus
params.visualizeEveryNFrames = 10;   % Nur jeden X-ten Frame zeichnen
params.dimOffsetY            = 45;   % Y-Offset für die Maßlinien
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
params.maxJumpDist_px   = 50; % Max. erlaubter X-Sprung pro Frame
params.minFramesTracked = 10; % Mindestanzahl an Frames für gültige Messung

% Position und Binning
params.kanalStart_mm = 0; % Position des rechten Bildrandes (Einlass) in mm
params.binSize_mm    = 3; % Rastergröße für die Fehlerbalken-Statistik (z.B. 3 mm)


%% 2. Video initialisieren & Setup
v = VideoReader(params.videoFile);
firstFrame = readFrame(v);
v.CurrentTime = 0;

if ndims(firstFrame) == 3
    firstFrameGray = rgb2gray(firstFrame); 
else
    firstFrameGray = firstFrame; 
end

fprintf('Starte Kalibrierung und ROI-Erkennung...\n');
[px2mm, roi, calibSuccess] = setup_Calibration(firstFrameGray, params.showCalibrationImage);

if ~calibSuccess
    warning('Automatische Kalibrierung fehlgeschlagen. Faktor px2mm = 1 gesetzt.');
else
    fprintf('Erfolgreich: %.5f mm/px\n', px2mm);
end

%% 3. Tracking Schleife
bubbleTracker = []; 
nextBubbleID = 1;
prevBubbleCentroids = []; 
channelHeightEstimate = NaN; % Wird im ersten Frame ermittelt
collected_UC_mm = []; % Speicher für Unit Cells initialisieren

if params.showVisuals
    hFig = figure('Name','Live Tracking', 'Position', [100 200 1000 300]); 
    hAx = axes(hFig);
end

frameIdx = 0;
startTime = tic;

fprintf('Starte Frame-Auswertung...\n');

while hasFrame(v)
    frameIdx = frameIdx + 1;
    I_full = readFrame(v);
    if ndims(I_full) == 3, I_full = rgb2gray(I_full); end
    I_roi = I_full(roi.y0:roi.y1, roi.x0:roi.x1);
    
    % detect_Bubbles liefert nun auch det und Unit Cells
    [currentBubbleCentroids, channelHeightEstimate, det, currentUC_px] = ...
        detect_Bubbles(I_roi, channelHeightEstimate, params);
        
    if ~isempty(currentUC_px)
        collected_UC_mm = [collected_UC_mm; currentUC_px * px2mm]; %#ok<AGROW>
    end
    
    [bubbleTracker, prevBubbleCentroids, nextBubbleID] = track_Bubbles(...
        currentBubbleCentroids, prevBubbleCentroids, bubbleTracker, nextBubbleID, frameIdx, params.maxJumpDist_px);
        
    % --- NEU: Live-Visualisierung ---
    if params.showVisuals && mod(frameIdx, params.visualizeEveryNFrames) == 0
        cla(hAx); imshow(I_roi, [], 'Parent', hAx); hold(hAx, 'on'); 
        title(hAx, sprintf('Frame %d', frameIdx));
        
        % 1. Blasenlängen und Maßlinien (Magenta) einzeichnen
        if numel(det) >= 2
            for j = 1:(numel(det)-1)
                x_e = det(j+1).rightX; x_s = det(j).leftX;
                y_e = det(j+1).rightY; y_s = det(j).leftY;
                dim_y = min(y_e, y_s) - params.dimOffsetY;
                
                plot(hAx, [x_e, x_e], [y_e, dim_y], 'm:', 'LineWidth', 1.5);
                plot(hAx, [x_s, x_s], [y_s, dim_y], 'm:', 'LineWidth', 1.5);
                plot(hAx, [x_e, x_s], [dim_y, dim_y], 'm-', 'LineWidth', 2);
                
                len_mm = (x_s - x_e) * px2mm;
                text(hAx, (x_e+x_s)/2, dim_y-15, sprintf('%.2f mm', len_mm), ...
                    'Color','m','FontWeight','bold','HorizontalAlignment','center');
            end
        end
        
        % 2. Tracking-Historie (Grüne Linien & IDs) einzeichnen
        for c = 1:size(prevBubbleCentroids, 1)
            currID = prevBubbleCentroids(c, 1);
            currX  = prevBubbleCentroids(c, 2);
            trkIdx = find(bubbleTracker(:, 1) == currID, 1, 'first');
            if ~isempty(trkIdx)
                startX_hist = bubbleTracker(trkIdx, 3);
                plot(hAx, [startX_hist, currX], [size(I_roi,1)/2+15, size(I_roi,1)/2+15], 'g-', 'LineWidth', 2);
                text(hAx, currX, size(I_roi,1)/2-15, sprintf('B%d', currID), ...
                    'Color','y','FontWeight','bold','HorizontalAlignment','center');
            end
        end
        hold(hAx, 'off'); drawnow;
    end
end

elapsedTime = toc(startTime);
fprintf('Tracking abgeschlossen in %.1f Sekunden (%d Frames).\n', elapsedTime, frameIdx);

if ~isempty(collected_UC_mm)
    fprintf('--- Unit Cell (UC) Auswertung ---\n');
    fprintf('Mittelwert der Unit Cell Länge (L_uc): %.3f mm\n\n', mean(collected_UC_mm));
end

%% 4. Auswertung der gekoppelten Physik
imgW = roi.x1 - roi.x0 + 1; 
% Berechne gemittelte Unit Cell (mit Fallback, falls keine gefunden wurde)
if isempty(collected_UC_mm), mean_UC_mm = 10; else, mean_UC_mm = mean(collected_UC_mm); end

[resultsTable, statsTable] = evaluate_Physics(bubbleTracker, px2mm, params.fps, ...
    params.minFramesTracked, imgW, params.kanalStart_mm, params.binSize_mm, mean_UC_mm);

visualize_Results(resultsTable, statsTable);
writetable(statsTable, 'Statistik_Ergebnisse_Kanallaenge.csv');
