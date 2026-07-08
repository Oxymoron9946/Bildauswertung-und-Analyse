% Skript zur Generierung des Kalibrierungs-Bildes für die Arbeit
clc; clear; close all;

% Pfad zum Export-Ordner wie in export_ScientificFigures.m
exportDir = '/home/sebastian/Sebastian/Studium/Forschungspraktikum/LaTex/Arbeit_Overleaf/images/Bildauswertung Original/';
if ~exist(exportDir, 'dir')
    mkdir(exportDir);
end

% Finde ein Kalibriervideo
baseDir = '/home/sebastian/Sebastian/Studium/Forschungspraktikum';
calibVideoFiles = dir(fullfile(baseDir, '**', 'Kalibrierung_*', '*.avi'));

if isempty(calibVideoFiles)
    error('Keine Kalibriervideos gefunden!');
end

% Nimm das erste gefundene Kalibriervideo
videoPath = fullfile(calibVideoFiles(1).folder, calibVideoFiles(1).name);
fprintf('Verwende Kalibriervideo: %s\n', videoPath);

vcalib = VideoReader(videoPath);
firstFrameGray = readFrame(vcalib);
if ndims(firstFrameGray) == 3
    firstFrameGray = rgb2gray(firstFrameGray);
end

% --- Kalibrierungslogik aus setup_Calibration.m ---
[imgH_full, imgW_full] = size(firstFrameGray);
px2mm = NaN; 
calibSuccess = false;

searchStartY = floor(imgH_full * 0.30);
searchEndY   = floor(imgH_full * 0.80);
searchArea   = firstFrameGray(searchStartY:searchEndY, :);

edgesV  = edge(searchArea, 'sobel', 'vertical');
rowSumV = sum(edgesV, 2);
[~, bestY_local] = max(rowSumV); 
bestY = bestY_local + searchStartY - 1;

y_start  = max(1, bestY - 60); 
y_end    = min(imgH_full, bestY + 15); 
x_margin = 25; 
rulerBand = double(firstFrameGray(y_start:y_end, x_margin:end-x_margin));

intensityProfile = mean(rulerBand, 1);
invertedProfile  = max(intensityProfile) - intensityProfile;
smoothedProfile  = smoothdata(invertedProfile, 'gaussian', 5);

prominenceThreshold = max(smoothedProfile) * 0.10; 
[~, locs] = findpeaks(smoothedProfile, 'MinPeakDistance', 8, 'MinPeakProminence', prominenceThreshold);

if length(locs) >= 10
    peakDiffs = diff(locs); 
    medianPx  = median(peakDiffs);
    valid_mask = abs(peakDiffs - medianPx) < (0.25 * medianPx);
    props = regionprops(bwlabel(valid_mask), 'Area', 'PixelIdxList');

    if ~isempty(props)
        [~, maxIdx] = max([props.Area]); 
        longestChainIdx = props(maxIdx).PixelIdxList;
        numIntervals = length(longestChainIdx);

        calibDistance_mm = numIntervals * 0.525; 

        firstTick_X_local = locs(longestChainIdx(1));
        lastTick_X_local  = locs(longestChainIdx(end) + 1);
        calibDistance_px  = lastTick_X_local - firstTick_X_local;

        if calibDistance_px > 0
            px2mm = calibDistance_mm / calibDistance_px;
            calibSuccess = true;

            global_locs      = locs(longestChainIdx) + x_margin - 1;
            global_firstTick = firstTick_X_local + x_margin - 1;
            global_lastTick  = lastTick_X_local + x_margin - 1;
            totalImageLength_mm = imgW_full * px2mm;
        end
    end
end

% --- Visualisierung und Export ---
hExp = figure('Visible', 'off', 'Position', [100, 100, 1200, 400]);
axExp = axes(hExp);
imshow(firstFrameGray, [], 'Parent', axExp); hold(axExp, 'on');

if calibSuccess
    bandRect = [x_margin, y_start, imgW_full - 2*x_margin, y_end - y_start];
    rectangle(axExp, 'Position', bandRect, 'EdgeColor', 'y', 'LineStyle', '--', 'LineWidth', 1);
    plot(axExp, global_locs, repmat(bestY, size(global_locs)), 'r|', 'MarkerSize', 12, 'LineWidth', 1.5);
    plot(axExp, [global_firstTick, global_lastTick], [bestY, bestY], 'g-', 'LineWidth', 1);
    title(axExp, sprintf('Massstab: %.5f mm/px | Messbereich: %.2f mm | Bildlaenge: %.2f mm', px2mm, calibDistance_mm, totalImageLength_mm));
else
    title(axExp, 'KALIBRIERUNG FEHLGESCHLAGEN!', 'Color', 'r');
end

hold(axExp, 'off');

exportPath = fullfile(exportDir, 'Abb0_Kalibrierung.png');
exportgraphics(hExp, exportPath, 'Resolution', 600);
fprintf('Bild erfolgreich gespeichert unter: %s\n', exportPath);

close(hExp);
