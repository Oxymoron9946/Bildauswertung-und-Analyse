function [resultsTable, statsTable] = evaluate_Physics(bubbleTracker, px2mm, fps, minFramesTracked, imgW, kanalStart_mm, binSize_mm, mean_UC_mm)
    if isempty(bubbleTracker)
        resultsTable = table(); statsTable = table(); return;
    end
    
    % Physikalische Konstanten
    d_channel = 1.0; 
    d_bubble  = 0.9; 
    A_channel = (pi/4) * d_channel^2; 
    A_bubble  = (pi/4) * d_bubble^2; 
    
    % Arrays für lokale Datenpunkte initialisieren
    all_IDs = []; all_X_mm = []; all_V_m_s = []; all_Vol_ul = [];
    
    uniqueIDs = unique(bubbleTracker(:, 1));
    for i = 1:length(uniqueIDs)
        bID = uniqueIDs(i);
        idx = find(bubbleTracker(:,1) == bID);
        
        % Ignoriere Blasen, die zu kurz getrackt wurden
        if length(idx) < minFramesTracked, continue; end
        
        % Daten der aktuellen Blase chronologisch sortieren
        trackData = sortrows(bubbleTracker(idx, :), 2); 
        frames = trackData(:, 2);
        x_px   = trackData(:, 3);
        len_px = trackData(:, 4);
        
        % Lokale Geschwindigkeit zwischen den Frames berechnen
        dx_px = -diff(x_px); % Negativ, da Fluss von rechts nach links (X wird kleiner)
        dframes = diff(frames);
        
        v_mm_s = (dx_px * px2mm) ./ (dframes / fps);
        v_m_s  = v_mm_s / 1000;
        
        % Zugehörige Position und Volumen in der Mitte des Schritts
        mid_x_px = (x_px(1:end-1) + x_px(2:end)) / 2;
        mid_len_px = (len_px(1:end-1) + len_px(2:end)) / 2;
        
        % Tracking-Ausreißer filtern (z.B. physikalisch unmögliche Geschwindigkeiten)
        valid = (v_m_s > 0) & (v_m_s < 5); 
        
        all_IDs = [all_IDs; repmat(bID, sum(valid), 1)];
        all_X_mm = [all_X_mm; mid_x_px(valid)];
        all_V_m_s = [all_V_m_s; v_m_s(valid)];
        all_Vol_ul = [all_Vol_ul; mid_len_px(valid) * px2mm * A_bubble];
    end
    
    % Absolute Position vom Eintritt (Rechter Bildrand = 0) berechnen
    distFromRight_mm = (imgW - all_X_mm) * px2mm;
    absolutePosX_mm = kanalStart_mm + distFromRight_mm;
    
    resultsTable = table(all_IDs, absolutePosX_mm, all_V_m_s, all_Vol_ul, ...
        'VariableNames', {'BubbleID', 'Position_X_mm', 'Speed_m_s', 'Volume_ul'});
    
    if isempty(resultsTable)
        statsTable = table(); return;
    end
    
    % Statistisches Binning
    xMin = floor(min(absolutePosX_mm)/binSize_mm)*binSize_mm;
    xMax = ceil(max(absolutePosX_mm)/binSize_mm)*binSize_mm;
    edges = xMin:binSize_mm:xMax;
    
    [binCount,~,binIdx] = histcounts(absolutePosX_mm, edges);
    binCenter = edges(1:end-1) + binSize_mm/2;
    
    % Gültige Messzone ermitteln
    nBins = numel(binCount);
    if nBins >= 3
        i0 = max(1, round(0.20*nBins)); i1 = min(nBins, round(0.80*nBins));
        isValid = binCount >= 0.50 * median(binCount(i0:i1));
        d = diff([false isValid false]);
        starts = find(d==1); ends = find(d==-1)-1;
        if isempty(starts)
            validStart_mm = NaN; validEnd_mm = NaN;
        else
            [~,k] = max(ends-starts);
            validStart_mm = edges(starts(k)); validEnd_mm = edges(ends(k)+1);
        end
    else
        validStart_mm = NaN; validEnd_mm = NaN;
    end
    
    inZone = (absolutePosX_mm >= validStart_mm) & (absolutePosX_mm <= validEnd_mm);
    if isnan(validStart_mm), inZone = true(size(absolutePosX_mm)); end
    
    resultsTable.BinCenter_mm = binCenter(binIdx)';
    statsTable = grpstats(resultsTable(inZone,:), 'BinCenter_mm', {'mean','std','numel'}, 'DataVars', {'Volume_ul', 'Speed_m_s'});
    
    % Erwartete Geschwindigkeit durch Volumenabnahme berechnen
    if height(statsTable) > 0
        v0_m_s = statsTable.mean_Speed_m_s(1);     
        V0_ul  = statsTable.mean_Volume_ul(1); 
        
        f_bubble = (v0_m_s * 1000) / mean_UC_mm; 
        delta_V_x = V0_ul - statsTable.mean_Volume_ul; 
        delta_v_x_mm_s = (f_bubble .* delta_V_x) / A_channel;
        
        statsTable.Expected_Speed_m_s = v0_m_s - (delta_v_x_mm_s / 1000);
    end
    
    statsTable.Properties.UserData = struct('validStart', validStart_mm, 'validEnd', validEnd_mm, 'firstMeas', min(absolutePosX_mm));
end
