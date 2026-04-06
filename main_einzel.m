%% Hauptskript: Gekoppelte Volumen- und Geschwindigkeitsmessung (Einzelvideo)
clc; close all; clear;

%% 1. Parameter & Konfiguration
% Wichtig: Die Pfade und FPS muessen an das jeweilige Video angepasst werden
params.videoFile = 'PVC_1mm_800um\Auswertung_20_CO2\Pos_1_Kal_1\0.134_0.25_Pos_1_R_1000_PVC_800\200fps_001\XSM-3520 Camera 0330_.avi';
params.calibFile = 'PVC_1mm_800um\Auswertung_20_CO2\Pos_1_Kal_1\Kalibrierung_1_Pos_1_26.03.2026_002\XSM-3520 Camera 0330_.avi';
params.fps = 200; % Entsprechend der Kamera-Einstellung (z.B. 200 oder 500)

% Visualisierung und Kontrolle
params.showCalibrationImage  = false; % Pop-up zur Ueberpruefung von ROI und Lineal
params.showVisuals           = true; % Live-Tracking an/aus (verlangsamt die Auswertung)
params.visualizeEveryNFrames = 10;    % Nur jeden X-ten Frame zeichnen
params.dimOffsetY            = 45;    % Y-Offset fuer die Masslinien in der Visualisierung

% Geometrie- und Bildfilter fuer Fluessigkeits-Slugs
params.minPixel     = 50;   % Minimum an Pixeln fuer ein Objekt
params.minArea      = 100;  % Minimum-Flaeche
params.minSolid     = 0.00; % Kompaktheit (Solidity)
params.maxSolid     = 1;
params.minEcc       = 0.00; % Exzentrizitaet (Abweichung von der Kreisform)
params.minAngle     = 0;    % Mindestwinkel
params.toleranceY   = 0.2;  % Toleranzband in der Mitte der Blase fuer die Kantenfindung
params.borderMargin = 2;    % Pixelabstand vom Bildrand, bei dem Blasen ignoriert werden

% Tracking Parameter
params.maxJumpDist_px   = 50; % Max. erlaubter X-Sprung pro Frame (in Pixel)
params.minFramesTracked = 10; % Mindestanzahl an Frames fuer gueltige Geschwindigkeitsmessung

% Position und physikalisches Binning
params.kanalStart_mm = 0; % Position des rechten Bildrandes (Einlass) in mm
params.binSize_mm    = 4; % Rastergroesse fuer die Fehlerbalken-Statistik

% PARAMETER FÜR BLASEN-FÜLLUNG (Möglichkeit 2) ---
params.closeWidth = 3;          % Breite des Schließ-Werkzeugs in Pixeln
params.closeHeight = 7;         % NEU: Höhe des Schließ-Werkzeugs (vertikal) zum Füllen vertikaler Lücken
params.showBinarySteps = true;   % Zeigt das Binärbild vor und nach dem Schließen

% --- ADAPTIVE SCHWELLENWERT-PARAMETER ---
params.sens = 0.75;              % Sensitivität (0 bis 1, höher = mehr Weiß)
params.neighborhoodSize = 51;    % NEU: Fenstergröße für lokalen Kontrast (MUSS ungerade sein!)
%% 2. Video initialisieren & Kalibrierung
v_calib = VideoReader(params.calibFile);
firstFrameCalib = readFrame(v_calib);

if ndims(firstFrameCalib) == 3
    firstFrameGray = rgb2gray(firstFrameCalib);
else
    firstFrameGray = firstFrameCalib;
end

fprintf('Starte Kalibrierung...\n');
% Die Funktion gibt keine ROI mehr zurück
[px2mm, calibSuccess] = setup_Calibration(firstFrameGray, params.showCalibrationImage);

if ~calibSuccess || isnan(px2mm)
    error('Automatische Kalibrierung fehlgeschlagen. Abbruch der Auswertung.');
else
    fprintf('Kalibrierung erfolgreich: %.5f mm/px\n', px2mm);
end

v = VideoReader(params.videoFile);
v.CurrentTime = 0; % Sicherstellen, dass das Video von vorne beginnt

imgH = v.Height;
imgW = v.Width;
roi.y0 = 1;
roi.y1 = imgH;
roi.x0 = 1;
roi.x1 = imgW;

roiHeight_px = roi.y1 - roi.y0 + 1;
roiHeight_mm = roiHeight_px * px2mm;
fprintf('Höhe des Bildausschnitts (ROI): %d Pixel (%.3f mm)\n', roiHeight_px, roiHeight_mm);

%% 3. Tracking Schleife (Frame by Frame)
bubbleTracker         = []; 
nextBubbleID          = 1;
prevBubbleCentroids   = []; 
channelHeightEstimate = NaN; % Wird im ersten Frame durch detect_Bubbles ermittelt
collected_UC_mm       = [];  % Speicher fuer detektierte Unit-Cells initialisieren

if params.showVisuals
    hFig = figure('Name','Live Tracking', 'Position', [100 200 1000 300]); 
    hAx  = axes(hFig);
end

frameIdx  = 0;
startTime = tic;

fprintf('Starte Frame-Auswertung...\n');

while hasFrame(v)
    frameIdx = frameIdx + 1;
    I_full   = readFrame(v);

    if ndims(I_full) == 3
        I_full = rgb2gray(I_full); 
    end

    % Bild auf den erkannten Kanal zuschneiden
    I_roi = I_full(roi.y0:roi.y1, roi.x0:roi.x1);

    %% 3.1 Blasen-Detektion
    [currentBubbleCentroids, channelHeightEstimate, det, currentUC_px, B_before, B_after] = ...
    detect_Bubbles(I_roi, channelHeightEstimate, params);

    if ~isempty(currentUC_px)
        % Pixel-Abstaende direkt in mm umrechnen und sammeln
        collected_UC_mm = [collected_UC_mm; currentUC_px * px2mm]; %#ok<AGROW>
    end

    %% 3.2 Zeitliches Tracking
    [bubbleTracker, prevBubbleCentroids, nextBubbleID] = track_Bubbles(...
        currentBubbleCentroids, prevBubbleCentroids, bubbleTracker, nextBubbleID, frameIdx, params.maxJumpDist_px);

    %% 3.3 Live-Visualisierung (Nur falls aktiviert)
    if params.showVisuals && mod(frameIdx, params.visualizeEveryNFrames) == 0
        cla(hAx); 
        imshow(I_roi, [], 'Parent', hAx); 
        hold(hAx, 'on'); 
        title(hAx, sprintf('Frame %d', frameIdx));

        % Masslinien fuer die Laengen der Slugs (Magenta) einzeichnen
        if numel(det) >= 2
            for j = 1:(numel(det)-1)
                x_e = det(j+1).rightX; 
                x_s = det(j).leftX;
                y_e = det(j+1).rightY; 
                y_s = det(j).leftY;
                dim_y = min(y_e, y_s) - params.dimOffsetY;

                plot(hAx, [x_e, x_e], [y_e, dim_y], 'm:', 'LineWidth', 1.5);
                plot(hAx, [x_s, x_s], [y_s, dim_y], 'm:', 'LineWidth', 1.5);
                plot(hAx, [x_e, x_s], [dim_y, dim_y], 'm-', 'LineWidth', 2);

                len_mm = (x_s - x_e) * px2mm;
                text(hAx, (x_e+x_s)/2, dim_y-15, sprintf('%.2f mm', len_mm), ...
                    'Color','m','FontWeight','bold','HorizontalAlignment','center');
            end
        end

        % Tracking-Historie (Gruene Linien & IDs) einzeichnen
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

        hold(hAx, 'off'); 
        drawnow;
                % --- NEU: Visualisierung der Binärbild-Schritte ---
        if isfield(params, 'showBinarySteps') && params.showBinarySteps
            if ~exist('hFigBin', 'var') || ~isvalid(hFigBin)
                hFigBin = figure('Name', 'Binärbild-Kontrolle', 'Position', [100 550 1000 300]);
            end
            figure(hFigBin);
            subplot(2,1,1); 
            imshow(I_roi); % Zeigt das echte Graustufenbild als Referenz
            title('Graustufenbild (Original ROI)');
            
            subplot(2,1,2); 
            % 'B_after' muss aus detect_Bubbles zurückgegeben werden
            imshow(B_after); 
            title(sprintf('Binarisiert (Sens=%.2f, NbSize=%d)', params.sens, params.neighborhoodSize));
        end
    end
end

elapsedTime = toc(startTime);
fprintf('Tracking abgeschlossen in %.1f Sekunden (%d Frames).\n', elapsedTime, frameIdx);

%% 4. Auswertung der Physik (Laengen & Geschwindigkeiten)
imgW = roi.x1 - roi.x0 + 1;
if isempty(collected_UC_mm)
    warning('Keine Unit Cells detektiert! Setze mean_UC auf NaN.');
    mean_UC_mm = NaN;
else
    mean_UC_mm = mean(collected_UC_mm);
    fprintf('--- Unit Cell (UC) Auswertung ---\n');
    fprintf('Mittelwert der Unit Cell Laenge (L_uc): %.3f mm\n\n', mean_UC_mm);
end

% Aufruf der aktualisierten evaluate_Physics
[resultsTable, statsTable] = evaluate_Physics(bubbleTracker, px2mm, params.fps, ...
    params.minFramesTracked, imgW, params.kanalStart_mm, params.binSize_mm, mean_UC_mm);

%% 5. Visualisierung & Speichern der Ergebnisse
visualize_Results(resultsTable, statsTable);
if ~isempty(statsTable)
    writetable(statsTable, 'Statistik_Ergebnisse_Kanallaenge.csv');
    fprintf('Ergebnisse als "Statistik_Ergebnisse_Kanallaenge.csv" gespeichert.\n');
end
