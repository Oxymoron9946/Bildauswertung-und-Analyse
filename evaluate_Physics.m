function [resultsTable, statsTable] = evaluate_Physics(bubbleTracker, px2mm, fps, minFramesTracked, imgW, kanalStart_mm, binSize_mm, mean_UC_mm)
% EVALUATE_PHYSICS Berechnet Geschwindigkeiten, Volumina und physikalische Zusammenhänge
%                  aus den getrackten Blasen-Daten.
%
% Eingaben:
%   bubbleTracker    - [N x 4] Matrix: [BubbleID, Frame, X_Centroid, Length]
%   px2mm            - Umrechnungsfaktor Pixel zu Millimeter
%   fps              - Bilder pro Sekunde (Kamera-Framerate)
%   minFramesTracked - Mindestanzahl an Frames, die eine Blase getrackt werden muss
%   imgW             - Bildbreite in Pixeln (zur Positionsbestimmung)
%   kanalStart_mm    - Reale X-Position des rechten Bildrandes (Kanal-Einlass) in mm
%   binSize_mm       - Rastergröße für die Fehlerbalken/Statistik in mm
%   mean_UC_mm       - Mittlere Unit-Cell-Länge in mm (NaN, falls unbekannt)
%
% Ausgaben:
%   resultsTable     - Tabelle mit Einzelmessungen (Position, Speed, Volumen) je ID
%   statsTable       - Tabelle mit gemittelten Werten je Position (Binning)

    %% 1. Initialisierung & Abbruchbedingung
    if isempty(bubbleTracker)
        resultsTable = table(); 
        statsTable = table(); 
        return;
    end
    
    %% 2. Physikalische Systemkonstanten (in mm bzw. mm^2)
    % Durchmesser und Querschnittsflächen von Kanal und Blase
    d_channel = 1.0; 
    d_bubble  = 1.0; 
    A_channel = d_channel^2; 
    A_bubble  = (pi/4) * d_bubble^2; 
    
    %% 3. Schleife über alle einzigartigen Blasen (Tracking-Auswertung)
    % Arrays für lokale Datenpunkte initialisieren
    all_IDs = []; 
    all_X_mm = []; 
    all_V_m_s = []; 
    all_Vol_ul = [];
    
    uniqueIDs = unique(bubbleTracker(:, 1));
    
    for i = 1:length(uniqueIDs)
        bID = uniqueIDs(i);
        idx = find(bubbleTracker(:,1) == bID);
        
        % Ausfiltern von Blasen, die zu kurz im Bild waren (Rauschen/Fehltracking)
        if length(idx) < minFramesTracked
            continue; 
        end
        
        % Daten der aktuellen Blase chronologisch (nach Frame) sortieren
        trackData = sortrows(bubbleTracker(idx, :), 2); 
        frames = trackData(:, 2);
        x_px   = trackData(:, 3);
        len_px = trackData(:, 4);
        
        %% 3.1 Lokale Geschwindigkeit berechnen (dx / dt)
        % Negatives Vorzeichen, da die Strömung von rechts (hohes X) nach links (tiefes X) fließt
        dx_px = -diff(x_px); 
        dframes = diff(frames);
        
        v_mm_s = (dx_px * px2mm) ./ (dframes / fps);
        v_m_s  = v_mm_s / 1000; % Umrechnung in m/s
        
        %% 3.2 Zugehörige Position und Volumen interpolieren
        % Werte auf die Mitte des Zeitschritts legen
        mid_x_px = (x_px(1:end-1) + x_px(2:end)) / 2;
        mid_len_px = (len_px(1:end-1) + len_px(2:end)) / 2;
        
        % Tracking-Ausreißer filtern (physikalisch unmögliche Geschwindigkeiten ignorieren)
        valid = (v_m_s > 0) & (v_m_s < 5); 
        
        % Validierte Daten an Gesamtarraays anhängen
        all_IDs = [all_IDs; repmat(bID, sum(valid), 1)];
        all_X_mm = [all_X_mm; mid_x_px(valid)];
        all_V_m_s = [all_V_m_s; v_m_s(valid)];
        
        % Volumenberechnung: Länge_mm * Querschnittsfläche_mm^2 = mm^3 (= Mikroliter, ul)
        all_Vol_ul = [all_Vol_ul; mid_len_px(valid) * px2mm * A_bubble]; 
    end
    
    %% 4. Absolute Kanalposition bestimmen & Einzel-Ergebnisse speichern
    % X-Koordinate in absolute Distanz vom Kanaleingang umrechnen
    distFromRight_mm = (imgW - all_X_mm) * px2mm;
    absolutePosX_mm = kanalStart_mm + distFromRight_mm;
    
    resultsTable = table(all_IDs, absolutePosX_mm, all_V_m_s, all_Vol_ul, ...
        'VariableNames', {'BubbleID', 'Position_X_mm', 'Speed_m_s', 'Volume_ul'});
    
    if isempty(resultsTable)
        statsTable = table(); 
        return;
    end
    
    %% 5. Statistisches Binning (Ortsaufgelöste Rasterung)
    % Ein Raster (Bins) basierend auf binSize_mm erstellen
    xMin = floor(min(absolutePosX_mm)/binSize_mm) * binSize_mm;
    xMax = ceil(max(absolutePosX_mm)/binSize_mm) * binSize_mm;
    edges = xMin:binSize_mm:xMax;
    
    [binCount,~,binIdx] = histcounts(absolutePosX_mm, edges);
    binCenter = edges(1:end-1) + binSize_mm/2;
    
    %% 6. Gültige Messzone (Plateau) identifizieren
    % Vermeidet verfälschte Randeffekte, wo Blasen ins Bild ein-/austreten
    nBins = numel(binCount);
    if nBins >= 3
        % Referenzwert aus dem mittleren 60%-Bereich nehmen
        i0 = max(1, round(0.20*nBins)); 
        i1 = min(nBins, round(0.80*nBins));
        
        % Ein Bin ist gültig, wenn er mind. 50% der Median-Messdichte erreicht
        isValid = binCount >= 0.50 * median(binCount(i0:i1));
        
        % Start und Ende der zusammenhängenden gültigen Zone finden
        d = diff([false isValid false]);
        starts = find(d==1); 
        ends = find(d==-1)-1;
        
        if isempty(starts)
            validStart_mm = NaN; 
            validEnd_mm = NaN;
        else
            [~,k] = max(ends-starts); % Längsten validen, zusammenhängenden Block wählen
            validStart_mm = edges(starts(k)); 
            validEnd_mm = edges(ends(k)+1);
        end
    else
        validStart_mm = NaN; 
        validEnd_mm = NaN;
    end
    
    %% 6.1 Validitäts-Prüfung und Warnungs-Handling
    % Welche Messpunkte liegen innerhalb der gültigen Messzone?
    inZone = (absolutePosX_mm >= validStart_mm) & (absolutePosX_mm <= validEnd_mm);
    
    % KEIN Fallback - Stattdessen Daten leer lassen und warnen.
    if isnan(validStart_mm)
        warning('Keine stabile Messzone gefunden. Setze inZone auf NaN (Statistik wird ignoriert).');
        inZone = false(size(absolutePosX_mm));
    end
    
    %% 7. Gruppierte Statistik (Mittelwerte & Standardabweichung pro Bin)
    resultsTable.BinCenter_mm = binCenter(binIdx)';
    
    % Statistik nur für Daten innerhalb der validen Zone berechnen
    statsTable = grpstats(resultsTable(inZone,:), 'BinCenter_mm', ...
        {'mean','std','numel'}, 'DataVars', {'Volume_ul', 'Speed_m_s'});
    
    %% 8. Gekoppelte Physik: Erwartete Geschwindigkeit aus Volumenabnahme
    if height(statsTable) > 0
        if isnan(mean_UC_mm)
            % Falls keine Unit-Cell ermittelt werden konnte
            warning('Unit-Cell-Länge (mean_UC_mm) ist NaN. Erwartete Geschwindigkeit wird übersprungen.');
            statsTable.Expected_Speed_m_s = NaN(height(statsTable), 1);
        else
            % Initiale Randbedingungen am Beginn der validen Messzone
            v0_m_s = statsTable.mean_Speed_m_s(1);     
            V0_ul  = statsTable.mean_Volume_ul(1); 
            
            % Blasenbildungsfrequenz (f) über Unit-Cell und Start-Geschwindigkeit berechnen
            f_bubble = (v0_m_s * 1000) / mean_UC_mm; 
            
            % Volumenabnahme entlang des Kanals relativ zum Eintritt berechnen
            delta_V_x = V0_ul - statsTable.mean_Volume_ul; 
            
            % Daraus resultierende Reduktion der Strömungsgeschwindigkeit
            delta_v_x_mm_s = (f_bubble .* delta_V_x) / A_channel;
            
            % Erwartete theoretische Geschwindigkeit eintragen
            statsTable.Expected_Speed_m_s = v0_m_s - (delta_v_x_mm_s / 1000);
        end
    end
    
    %% 9. Metadaten zur Statistik-Tabelle hinzufügen
    statsTable.Properties.UserData = struct( ...
        'validStart', validStart_mm, ...
        'validEnd', validEnd_mm, ...
        'firstMeas', min(absolutePosX_mm));
end
