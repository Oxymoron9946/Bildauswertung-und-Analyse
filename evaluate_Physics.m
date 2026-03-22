function [resultsTable, statsTable] = evaluate_Physics(bubbleTracker, px2mm, fps, minFramesTracked, imgW, kanalStart_mm, binSize_mm, mean_UC_mm)
% EVALUATE_PHYSICS Berechnet Geschwindigkeiten und lokale Längen im Taylor-Flow.
%
% Eingaben:
% bubbleTracker - [N x 5] Matrix: [ID, Frame, X_Start_UC_px, BubbleLen_px, UC_Len_px]
% px2mm - Umrechnungsfaktor Pixel zu Millimeter
% fps - Bilder pro Sekunde (Kamera-Framerate)
% minFramesTracked - Mindestanzahl an Frames, die eine Blase getrackt werden muss
% imgW - Bildbreite in Pixeln (zur Positionsbestimmung)
% kanalStart_mm - Reale X-Position des rechten Bildrandes in mm
% binSize_mm - Rastergröße für die Statistik in mm
% mean_UC_mm - Mittlere globale Unit-Cell-Länge (wird hier nicht mehr zwingend benötigt, da wir lokal tracken!)

%% 1. Initialisierung & Abbruchbedingung
if isempty(bubbleTracker) || size(bubbleTracker, 2) < 5
    resultsTable = table();
    statsTable = table();
    return;
end

%% 2. Schleife über alle einzigartigen Blasen (Tracking-Auswertung)
all_IDs = [];
all_X_mm = [];
all_V_m_s = [];
all_BubbleLength_mm = [];
all_UnitCell_mm = [];
all_SlugLength_mm = [];
all_VoidFraction = [];

uniqueIDs = unique(bubbleTracker(:, 1));

for i = 1:length(uniqueIDs)
    bID = uniqueIDs(i);
    idx = find(bubbleTracker(:,1) == bID);
    
    if length(idx) < minFramesTracked
        continue;
    end
    
    % Daten chronologisch sortieren
    trackData = sortrows(bubbleTracker(idx, :), 2);
    frames = trackData(:, 2);
    x_px = trackData(:, 3);      % Start-Koordinate der Unit-Cell!
    bubble_len_px = trackData(:, 4);
    uc_len_px = trackData(:, 5); % NEU: Lokale Unit-Cell Länge
    
    %% 3.1 Lokale Geschwindigkeit berechnen (dx / dt)
    % Negatives Vorzeichen, da Strömung von rechts (hohes X) nach links (tiefes X)
    dx_px = -diff(x_px);
    dframes = diff(frames);
    v_mm_s = (dx_px * px2mm) ./ (dframes / fps);
    v_m_s = v_mm_s / 1000;
    
    %% 3.2 Zugehörige Längen interpolieren (Werte auf die Mitte des Zeitschritts legen)
    mid_x_px = (x_px(1:end-1) + x_px(2:end)) / 2;
    mid_bubble_len_px = (bubble_len_px(1:end-1) + bubble_len_px(2:end)) / 2;
    mid_uc_len_px = (uc_len_px(1:end-1) + uc_len_px(2:end)) / 2;
    
    % Tracking-Ausreißer filtern
    valid = (v_m_s > 0) & (v_m_s < 5);
    
    if sum(valid) == 0
        continue;
    end
    
    %% 3.3 Neue lokale Längen berechnen (in mm)
    bubble_len_mm = mid_bubble_len_px(valid) * px2mm;
    uc_len_mm = mid_uc_len_px(valid) * px2mm;
    slug_len_mm = uc_len_mm - bubble_len_mm;
    void_frac = bubble_len_mm ./ uc_len_mm;
    
    % Validierte Daten an Arrays anhängen
    all_IDs = [all_IDs; repmat(bID, sum(valid), 1)];
    all_X_mm = [all_X_mm; mid_x_px(valid)];
    all_V_m_s = [all_V_m_s; v_m_s(valid)];
    
    all_BubbleLength_mm = [all_BubbleLength_mm; bubble_len_mm];
    all_UnitCell_mm = [all_UnitCell_mm; uc_len_mm];
    all_SlugLength_mm = [all_SlugLength_mm; slug_len_mm];
    all_VoidFraction = [all_VoidFraction; void_frac];
end

%% 4. Absolute Kanalposition bestimmen & Ergebnisse in Table packen
% X-Koordinate (ausgehend vom rechten Bildrand) in reale Distanz umrechnen
distFromRight_mm = (imgW - all_X_mm) * px2mm;
absolutePosX_mm = kanalStart_mm + distFromRight_mm;

resultsTable = table(all_IDs, absolutePosX_mm, all_V_m_s, ...
    all_BubbleLength_mm, all_UnitCell_mm, all_SlugLength_mm, all_VoidFraction, ...
    'VariableNames', {'BubbleID', 'Position_X_mm', 'Speed_m_s', ...
    'BubbleLength_mm', 'UnitCellLength_mm', 'SlugLength_mm', 'VoidFraction'});

if isempty(resultsTable)
    statsTable = table();
    return;
end

%% 5. Statistisches Binning (Ortsaufgelöste Rasterung)
% Bin-Größe an mittlere Blasenlänge anpassen
meanBubbleLength_mm = mean(all_BubbleLength_mm);
if binSize_mm < meanBubbleLength_mm
    binSize_mm = ceil(meanBubbleLength_mm * 2) / 2;
end

xMin = floor(min(absolutePosX_mm)/binSize_mm) * binSize_mm;
xMax = ceil(max(absolutePosX_mm)/binSize_mm) * binSize_mm;
edges = xMin:binSize_mm:xMax;

[binCount,~,binIdx] = histcounts(absolutePosX_mm, edges);
binCenter = edges(1:end-1) + binSize_mm/2;
resultsTable.BinCenter_mm = binCenter(binIdx)';

%% 6. Gültige Messzone (Plateau) identifizieren
nBins = numel(binCount);
if nBins >= 3
    i0 = max(1, round(0.20*nBins));
    i1 = min(nBins, round(0.80*nBins));
    isValid = binCount >= 0.50 * median(binCount(i0:i1));
    d = diff([false isValid false]);
    starts = find(d==1);
    ends = find(d==-1)-1;
    
    if isempty(starts)
        validStart_mm = NaN;
        validEnd_mm = NaN;
    else
        [~,k] = max(ends-starts);
        validStart_mm = edges(starts(k));
        validEnd_mm = edges(ends(k)+1);
    end
else
    validStart_mm = NaN;
    validEnd_mm = NaN;
end

inZone = (absolutePosX_mm >= validStart_mm) & (absolutePosX_mm <= validEnd_mm);

if isnan(validStart_mm)
    warning('Keine stabile Messzone gefunden.');
    inZone = false(size(absolutePosX_mm));
end

%% 7. Gruppierte Statistik (Mittelwerte pro Bin)
statsTable = grpstats(resultsTable(inZone,:), 'BinCenter_mm', ...
    {'mean','std','numel'}, 'DataVars', {'BubbleLength_mm', 'UnitCellLength_mm', 'SlugLength_mm', 'VoidFraction', 'Speed_m_s'});

%% 8. Metadaten zur Statistik-Tabelle hinzufügen
statsTable.Properties.UserData = struct( ...
    'validStart', validStart_mm, ...
    'validEnd', validEnd_mm, ...
    'firstMeas', min(absolutePosX_mm));
end
