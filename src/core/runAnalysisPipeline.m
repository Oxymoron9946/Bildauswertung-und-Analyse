function [resultsTable, statsTable, mean_UC_mm, L_ein_mm] = runAnalysisPipeline(videoFile, calibFile, config, params)
% RUNANALYSISPIPELINE Führt die komplette Videoauswertung für ein Video durch.
%
% Eingaben:
%   videoFile - Pfad zum Messvideo (.avi)
%   calibFile - Pfad zum Kalibriervideo (.avi)
%   config    - Der hierarchische Konfigurations-Struct
%   params    - Der flache Parameter-Struct (temporärer Adapter für alte Kernfunktionen)
%
% Ausgaben:
%   resultsTable - Tabelle mit allen getrackten Blasen
%   statsTable   - Tabelle mit den gebinnten physikalischen Ergebnissen
%   mean_UC_mm   - Mittlere Unit-Cell-Länge
%   L_ein_mm     - Berechnete hydrodynamische Einlauflänge

    %% 1. Kalibrierung
    v_calib = VideoReader(calibFile);
    firstFrameCalib = readFrame(v_calib);
    if ndims(firstFrameCalib) == 3
        firstFrameGray = rgb2gray(firstFrameCalib);
    else
        firstFrameGray = firstFrameCalib;
    end

    if config.ui.showVisuals
        fprintf('Starte Kalibrierung...\n');
    end
    
    [px2mm, calibSuccess] = setup_Calibration(firstFrameGray, params.showCalibrationImage);
    if ~calibSuccess || isnan(px2mm)
        error('Automatische Kalibrierung fehlgeschlagen. Abbruch der Auswertung.');
    end

    %% 2. Video initialisieren
    v = VideoReader(videoFile);
    v.CurrentTime = 0;

    imgH = v.Height;
    imgW = v.Width;
    roi.y0 = 1;
    roi.y1 = imgH;
    roi.x0 = 1;
    roi.x1 = imgW;

    %% 3. Tracking Schleife (Frame by Frame)
    bubbleTracker         = []; 
    nextBubbleID          = 1;
    prevBubbleCentroids   = []; 
    channelState = struct('locked', false, 'initFramesTarget', 10, 'frameCount', 0, ...
        'samplesTop', [], 'samplesBot', [], 'x_support', [], 'y_top_line', [], ...
        'y_bot_line', [], 'y_mid_line', [], 'width_ref', [], 'heightEstimate', NaN, ...
        'validTopMask', [], 'validBotMask', []);
    collected_UC_mm       = [];  

    if params.showVisuals
        % Prüfen, ob wir aus der App heraus aufgerufen wurden
        if isfield(config.ui, 'appAxes') && ~isempty(config.ui.appAxes) && isvalid(config.ui.appAxes)
            hAx = config.ui.appAxes;
        else
            % Fallback für Skript-Aufruf
            hFig = figure('Name','Live Tracking', 'Position', [100 200 1000 300]); 
            hAx  = axes(hFig);
        end
    end

    frameIdx  = 0;
    startTime = tic;

    while hasFrame(v)
        frameIdx = frameIdx + 1;
        I_full   = readFrame(v);
        if ndims(I_full) == 3
            I_full = rgb2gray(I_full); 
        end
        I_roi = I_full(roi.y0:roi.y1, roi.x0:roi.x1);

        % 3.1 Detektion
        [currentBubbleCentroids, channelState, det, currentUC_px, B_before, B_after, seeds] = ...
            detect_Bubbles(I_roi, channelState, params);

        if ~isempty(currentUC_px)
            collected_UC_mm = [collected_UC_mm; currentUC_px * px2mm]; %#ok<AGROW>
        end

        % 3.2 Tracking
        [bubbleTracker, prevBubbleCentroids, nextBubbleID] = track_Bubbles(...
            currentBubbleCentroids, prevBubbleCentroids, bubbleTracker, nextBubbleID, frameIdx, params.maxJumpDist_px);

        % 3.3 Export
        if params.exportImages
            export_ScientificFigures(I_roi, B_before, B_after, seeds, det, channelState.heightEstimate, params, frameIdx, px2mm);
        end

        % 3.4 Live-Visualisierung
        if params.showVisuals && mod(frameIdx, params.visualizeEveryNFrames) == 0
            cla(hAx); 
            % imshow verhält sich in UIAxes manchmal zickig, imagesc ist robuster
            imagesc(hAx, I_roi);
            colormap(hAx, gray);
            axis(hAx, 'image'); % Korrekte Proportionen
            hold(hAx, 'on');
            text(hAx, imgW/2, -30, sprintf('Frame %d - Channel Detection & Tracking', frameIdx), ...
                'Color', 'k', 'FontWeight', 'bold', 'FontSize', 12, 'HorizontalAlignment', 'center');
            
            if exist('seeds', 'var') && ~isempty(seeds)
                % 1. Das berechnete/gesperrte Kanalmodell in ROT einzeichnen
                if isfield(seeds, 'y_top_line') && ~isempty(seeds.y_top_line)
                    plot(hAx, 1:length(seeds.y_top_line), seeds.y_top_line, 'r-', 'LineWidth', 1.5);
                    plot(hAx, 1:length(seeds.y_bot_line), seeds.y_bot_line, 'r-', 'LineWidth', 1.5);
                end
            end

            % 2. Blasen-Grenzen (Links/Rechts) und Längenangabe (mm) einzeichnen
            if exist('det', 'var') && ~isempty(det) && exist('seeds', 'var') && isfield(seeds, 'y_top_line')
                for d = 1:length(det)
                    lx = det(d).leftX;
                    rx = det(d).rightX;
                    
                    % Vertikale Linien: Links Grün, Rechts Rot
                    plot(hAx, [lx, lx], [seeds.y_top_line(lx), seeds.y_bot_line(lx)], 'g-', 'LineWidth', 1.5);
                    plot(hAx, [rx, rx], [seeds.y_top_line(rx), seeds.y_bot_line(rx)], 'r-', 'LineWidth', 1.5);
                    
                    % Horizontale Linie über der Blase (Magenta)
                    y_text_pos = seeds.y_top_line(round((lx+rx)/2)) - 25;
                    plot(hAx, [lx, rx], [y_text_pos+5, y_text_pos+5], 'm-', 'LineWidth', 1);
                    
                    % Text mit Länge (Zahl oben, "mm" in der nächsten Zeile)
                    len_mm = (rx - lx) * px2mm;
                    text(hAx, (lx+rx)/2, y_text_pos, sprintf('%.2f\nmm', len_mm), ...
                        'Color', 'm', 'FontWeight', 'bold', 'HorizontalAlignment', 'center', 'FontSize', 14);
                end
            end
            hold(hAx, 'off');
            drawnow;

            % Abbruch durch Benutzer prüfen (Stop-Button in der GUI)
            if isfield(config.ui, 'appFigure') && ~isempty(config.ui.appFigure) && ...
               isvalid(config.ui.appFigure) && config.ui.appFigure.UserData.CancelRequested
                fprintf('Abbruch durch Benutzer.\n');
                break;
            end
        end
    end

    if config.ui.showVisuals
        fprintf('Tracking abgeschlossen in %.1f Sekunden (%d Frames).\n', toc(startTime), frameIdx);
    end

    %% 4. Auswertung der Physik
    L_ein_mm = NaN;
    paramTokens = regexp(videoFile, '(?<gas>[\d\.]+)_(?<liq>[\d\.]+)_Pos_(?<pos>\d+)_(?<form>[A-Za-z]+)_(?<kanal>\d+)_(?<mat>[A-Za-z]+)_(?<nadel>\d+)', 'names');
    if ~isempty(paramTokens)
        j_G = str2double(paramTokens.gas);
        j_L = str2double(paramTokens.liq);
        d_h_mm = str2double(paramTokens.kanal) / 1000; 
        Re = (1000 * (j_G + j_L) * (d_h_mm / 1000)) / 0.001;
        L_ein_mm = 0.05 * Re * d_h_mm;
    end

    if isempty(collected_UC_mm)
        mean_UC_mm = NaN;
    else
        mean_UC_mm = mean(collected_UC_mm);
    end

    [resultsTable, statsTable] = evaluate_Physics(bubbleTracker, px2mm, params.fps, ...
        params.minFramesTracked, imgW, params.kanalStart_mm, params.binSize_mm, mean_UC_mm, L_ein_mm);
end