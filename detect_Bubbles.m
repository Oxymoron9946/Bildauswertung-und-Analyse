function [currentBubbleCentroids, channelHeightEstimate, det, currentUC_px, B_before, B_after] = detect_Bubbles(I, channelHeightEstimate, params)
% DETECT_BUBBLES Erkennt Flüssigkeits-Slugs und misst Unit-Cells im Taylor-Flow.
%
% EINGABEN:
%   I                     - Graustufenbild (bereits auf die Region of Interest zugeschnitten)
%   channelHeightEstimate - Bisherige Schätzung der Kanalhöhe in Pixeln (NaN, wenn noch unbestimmt)
%   params                - Struktur mit Filter- und Toleranzparametern
%
% AUSGABEN:
%   currentBubbleCentroids - [N x 3] Matrix: [UC_Start_X, Bubble_Length_px, UC_Length_px]
%   channelHeightEstimate  - Berechnete oder beibehaltene Kanalhöhe in Pixeln
%   det                    - Struct mit den genauen Kantenkoordinaten der detektierten Slugs
%   currentUC_px           - Vektor mit den Längen der Unit-Cells in Pixeln
%   B_before               - Binärbild VOR den morphologischen Operationen (zur Diagnose)
%   B_after                - Binärbild NACH den morphologischen Operationen (zur Diagnose)

    %% 1. Initialisierung & Bildvorbereitung
    [imgH, imgW] = size(I);
    currentBubbleCentroids = [];
    currentUC_px = []; 
    det = []; % Standard-Rückgabe, falls in diesem Frame nichts gefunden wird
    
    % Kontrastverbesserung (CLAHE): Macht dunkle Bildbereiche heller und umgekehrt.
    % Extrem wichtig, damit die Ausleuchtung im gesamten Kanal gleichmäßig ist.
    I_eq = adapthisteq(I, 'NumTiles', [4 8], 'ClipLimit', 0.01);
    
    % Median-Filter (Glätten): Entfernt winzige "Salz & Pfeffer"-Artefakte an den 
    % Kanten der Blasen, bevor binarisiert wird. Macht die Kantenfindung robuster.
    I_eq = medfilt2(I_eq, [3 3]); 
    
    %% 2. Binarisierung & Rauschunterdrückung
    % Sensitivität abfragen (Standard: 0.5, falls im Hauptskript nicht definiert)
    if isfield(params, 'sens'), s = params.sens; else, s = 0.5; end
    
    % Adaptive Thresholding: Berechnet für jeden Pixel einen eigenen Schwellenwert
    % basierend auf seiner Umgebung (Neighborhood).
    if isfield(params, 'neighborhoodSize')
        nbSize = floor(size(I_eq, 1) / 2);
        if mod(nbSize, 2) == 0, nbSize = nbSize - 1; end % Muss ungerade sein
    else
        % Fallback: Standardmäßig ca. 1/8 der Bildhöhe (und auf ungerade Zahl gezwungen)
        nbSize = 2 * floor(size(I_eq,1)/16) + 1; 
    end
    
    % Erstelle die lokale Schwellenwert-Matrix
    T = adaptthresh(I_eq, s, 'ForegroundPolarity', 'bright', 'NeighborhoodSize', [nbSize nbSize]);
    
    % Binarisiere das Bild anhand dieser genauen Matrix (Schwarz-Weiß-Bild)
    B_before = imbinarize(I_eq, T);
    
    % --- VERTIKALES SCHLIEßEN (Lücken in Y-Richtung füllen) ---
    % Wenn Ränder der Slugs leicht aufgerissen sind, werden sie mit einem
    % vertikalen "Balken" (imopen) wieder repariert / geschlossen.
    if isfield(params, 'closeHeight') && params.closeHeight > 1
        se_vert = strel('rectangle', [params.closeHeight, 1]); 
        B_before = imopen(B_before, se_vert);
    end
    
    % --- HORIZONTALES SCHLIEßEN (imopen) ---
    % Löscht alle weißen Flächen (wie Spiegelungen im Blaseninneren), die horizontal 
    % schmaler sind als 'closeWidth'. Die massiven weißen Slugs bleiben erhalten.
    if isfield(params, 'closeWidth'), w = params.closeWidth; else, w = 1; end
    se = strel('rectangle', [1, w]); 
    B_after = imopen(B_before, se);
    
    % Löcher innerhalb der identifizierten weißen Slugs mit Weiß füllen
    B_after = imfill(B_after, 'holes'); 
    
    % Alle Objekte löschen, die aus weniger Pixeln als 'minPixel' bestehen (Staub/Rauschen)
    B = bwareaopen(B_after, params.minPixel);
    
    %% 3. Labeling & Vorfilterung der Objekte
    % bwlabel gibt jedem getrennten weißen Objekt eine eigene Nummer (1, 2, 3...)
    [L, num] = bwlabel(B);
    
    % Für eine Unit-Cell (Slug + Blase) werden mindestens zwei Slugs im Bild benötigt.
    % Gibt es weniger, können wir nichts messen -> Abbruch für diesen Frame.
    if num < 2 
        return; 
    end
    
    % Einfache Merkmale (Fläche und die umschließende Box) für alle Objekte berechnen
    statsBasic = regionprops(L, 'Area', 'BoundingBox');
    
    % Nur Objekte betrachten, die groß genug sind (minArea)
    candidateIdx = find([statsBasic.Area] > params.minArea);
    if isempty(candidateIdx)
        return; 
    end
    
    %% 4. Dynamische Bestimmung der Kanalhöhe
    % Dies passiert in der Regel nur im allerersten Frame, wenn noch kein Wert bekannt ist.
    if isnan(channelHeightEstimate)
        % BoundingBoxes aller Kandidaten extrahieren. Format: [X, Y, Breite, Höhe]
        candidateHeights = [statsBasic(candidateIdx).BoundingBox];
        candidateHeights = candidateHeights(4:4:end); % Greife nur auf jedes 4. Element (die Höhe) zu
        
        if length(candidateHeights) >= 4
            % Sortieren und den Median der größeren Hälfte nehmen, 
            % um flache Störobjekte zu ignorieren
            sortedH = sort(candidateHeights);
            channelHeightEstimate = median(sortedH(ceil(end/2):end));
        else
            % Nicht genug Daten im ersten Frame -> Warnung, aber noch keine Werte setzen.
            warning('Kanalhöhe konnte nicht zuverlässig bestimmt werden (zu wenig Objekte). Setze auf NaN.');
            channelHeightEstimate = NaN;
            return; % Frame abbrechen. Wir versuchen es im nächsten Frame erneut.
        end
    end
    
    %% 5. Detaillierte Merkmalsberechnung für gültige Kandidaten
    % Berechne genauere physikalische Eigenschaften (hier brauchen wir nur den Centroid)
    statsFull = regionprops(L, 'Centroid');
    
    % Struktur vorbereiten, um die finalen validierten Slugs abzuspeichern
    det = struct('cx',{},'leftX',{},'leftY',{},'rightX',{},'rightY',{},'bb',{});
    
    for k = candidateIdx
        bb = statsBasic(k).BoundingBox;
        
        %% 5.1 Plausibilitätsprüfungen (Geometrie & Lage)
        % 1. Ein echter Slug muss mindestens 80% der vorher ermittelten Kanalhöhe einnehmen
        if bb(4) < 0.90 * channelHeightEstimate
            continue; 
        end
        
        % 2. Der Slug muss sich grob in der vertikalen Bildmitte befinden
        if abs(statsFull(k).Centroid(2) - imgH/2) > (imgH * 0.40)
            continue; 
        end
        
        % 3. Ignoriere Objekte, die direkt an den linken oder rechten Bildrand klatschen.
        % Diese sind oft abgeschnitten und verfälschen Längenmessungen.
        if bb(1) <= 1 || (bb(1) + bb(3)) >= imgW
            continue;
        end
        
        %% 5.2 Lokale Kantenbestimmung über den Perimeter
        % Begrenzungsbox so definieren, dass sie sicher nicht über den Bildrand hinausragt
        bx0 = max(1, floor(bb(1))); 
        by0 = max(1, floor(bb(2)));
        bx1 = min(imgW, ceil(bb(1)+bb(3)-1)); 
        by1 = min(imgH, ceil(bb(2)+bb(4)-1));
        
        if bx1 <= bx0 || by1 <= by0
            continue; 
        end
        
        % Lokalen Bildausschnitt für dieses Objekt generieren und Randpixel finden
        subL = L(by0:by1, bx0:bx1);
        [rP, cP] = find(bwperim(subL == k, 8)); 
        if isempty(rP)
            continue; 
        end
        
        %% 5.3 Präzise Identifikation der linken und rechten Kante
        cx_local = statsFull(k).Centroid(1) - bx0 + 1; % Lokaler Mittelpunkt in X
        spanY = max(rP) - min(rP);                     % Gesamthöhe des Objekts
        midY = (min(rP)+max(rP))/2;                    % Vertikale Mitte
        
        % Filtern: Nur Randpixel betrachten, die im waagerechten "Toleranzband" in der Mitte liegen
        inBand = (rP >= midY - spanY*params.toleranceY) & (rP <= midY + spanY*params.toleranceY);
        cBand = cP(inBand); 
        rBand = rP(inBand);
        
        if isempty(cBand)
            continue; 
        end
        
        % Trenne die Randpixel auf: Welche liegen links vom Zentrum, welche rechts?
        leftMask = cBand < cx_local; 
        rightMask = cBand >= cx_local;
        
        if ~any(leftMask) || ~any(rightMask)
            continue; 
        end
        
        % --- ROBUSTE KANTENFINDUNG (Ignoriert einzelne Staubkörner am Rand) ---
        % Statt einfach den extremsten Randpunkt zu nehmen, bestimmen wir für jede Y-Höhe 
        % den Randpunkt und nehmen den Median dieser Randpunkte.
        
        % 1. Linke Kante
        y_left = unique(rBand(leftMask));
        x_left_profile = zeros(size(y_left));
        for i = 1:length(y_left)
            x_left_profile(i) = max(cBand(leftMask & rBand == y_left(i))); % Der rechteste Punkt pro Y-Höhe
        end
        left_x_local = round(median(x_left_profile)); 
        
        % 2. Rechte Kante
        y_right = unique(rBand(rightMask));
        x_right_profile = zeros(size(y_right));
        for i = 1:length(y_right)
            x_right_profile(i) = min(cBand(rightMask & rBand == y_right(i))); % Der linkeste Punkt pro Y-Höhe
        end
        right_x_local = round(median(x_right_profile));
        
        % Speichere das fertig vermessene, validierte Objekt in die Struktur
        det(end+1) = struct( ...
            'cx', statsFull(k).Centroid(1), ...
            'leftX', left_x_local + bx0 - 1, ...
            'leftY', round(midY) + by0 - 1, ...
            'rightX', right_x_local + bx0 - 1, ...
            'rightY', round(midY) + by0 - 1, ... 
            'bb', [bx0 by0 (bx1-bx0+1) (by1-by0+1)]);
    end
    
    %% 6. Auswertung der erkannten Objekte
    % Wenn nach dem harten Filtern weniger als 2 Slugs übrig sind, abbrechen.
    if numel(det) < 2
        return; 
    end
    
    % Sortiere die Slugs von rechts nach links (da die Strömung so verläuft)
    [~, sIdx] = sort([det.cx], 'descend');
    det = det(sIdx);
    
    %% 7. Berechnung von Unit-Cells (Gekoppeltes Tracking)
    for j = 1:(numel(det)-1)
        
        % Fallback gegen Fehler am Bildrand
        bbLeft = det(j).bb;
        bbRight = det(j+1).bb;
        if isfield(params, 'borderMargin')
            bMarg = params.borderMargin;
        else
            bMarg = 2;
        end
        if bbLeft(1) <= bMarg || (bbRight(1) + bbRight(3)) >= (imgW - bMarg)
            continue;
        end
        
        % --- 1. Unit Cell (UC) definieren ---
        % Beginnt an linker Kante des aktuellen Slugs und endet an linker Kante des nächsten Slugs
        uc_start_x = det(j).leftX;
        uc_end_x   = det(j+1).leftX;
        uc_len_px  = abs(uc_start_x - uc_end_x);
        
        % --- 2. Blase innerhalb dieser UC messen ---
        % Die Blase liegt genau zwischen den beiden Slugs
        bubble_right_x = det(j+1).rightX;
        bubble_left_x  = det(j).leftX;
        bubble_len_px  = bubble_left_x - bubble_right_x;
        
        % --- 3. Daten speichern ---
        % Wenn die Werte physikalisch Sinn machen, speichern wir sie für den Tracker.
        % Struktur für Tracker: [Start_X_der_UnitCell, Blasenlänge, UnitCell_Länge]
        if bubble_len_px > 0 && uc_len_px > bubble_len_px
            currentBubbleCentroids = [currentBubbleCentroids; uc_start_x, bubble_len_px, uc_len_px]; %#ok
            currentUC_px = [currentUC_px; uc_len_px]; %#ok
        end
    end
end