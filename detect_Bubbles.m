function [currentBubbleCentroids, channelHeightEstimate, det, currentUC_px, B_before, B_after] = detect_Bubbles(I, channelHeightEstimate, params)

% DETECT_BUBBLES Erkennt Flüssigkeits-Slugs und misst Unit-Cells im Taylor-Flow.
%
% Eingaben:
%   I                     - Graustufenbild (bereits auf die ROI zugeschnitten)
%   channelHeightEstimate - Bisherige Schätzung der Kanalhöhe in Pixeln (NaN für Init)
%   params                - Struktur mit Filter- und Toleranzparametern
%
% Ausgaben:
%   currentBubbleCentroids - [N x 2] Matrix mit [Mittelpunkt_X, Laenge_px]
%   channelHeightEstimate  - Berechnete oder beibehaltene Kanalhöhe in Pixeln
%   det                    - Struct mit den genauen Kantenkoordinaten der Slugs
%   currentUC_px           - Vektor mit den Längen der Unit-Cells in Pixeln

    %% 1. Initialisierung & Bildvorbereitung
    [imgH, imgW] = size(I);
    currentBubbleCentroids = [];
    currentUC_px = []; 
    det = []; % Standard-Rückgabe, falls abgebrochen wird
    
    % Kontrastverbesserung (CLAHE) für robustere Binarisierung
    I_eq = adapthisteq(I, 'NumTiles', [4 8], 'ClipLimit', 0.01);

    % --- NEU: Leichtes Glätten zur Rauschunterdrückung vor dem Binarisieren ---
    I_eq = medfilt2(I_eq, [3 3]); % Entfernt "Salz & Pfeffer"-Rauschen in den Rändern
    
   %% 2. Binarisierung & Rauschunterdrückung
    if isfield(params, 'sens'), s = params.sens; else, s = 0.5; end

    % NeighborhoodSize abrufen und sicherstellen, dass sie ungerade ist
    if isfield(params, 'neighborhoodSize')
        nbSize = floor(size(I_eq, 1) / 2);
        if mod(nbSize, 2) == 0, nbSize = nbSize - 1; end % Muss ungerade sein
    else
        % Fallback: Standardmäßig ca. 1/8 der Bildhöhe (ungerade gemacht)
        nbSize = 2 * floor(size(I_eq,1)/16) + 1; 
    end

    % 1. Erstelle die lokale Schwellenwert-Matrix mit adaptthresh
    T = adaptthresh(I_eq, s, 'ForegroundPolarity', 'bright', 'NeighborhoodSize', [nbSize nbSize]);
    
    % 2. Binarisiere das Bild anhand dieser genauen Matrix
    B_before = imbinarize(I_eq, T);
    
    % --- NEU: VERTIKALES SCHLIEßEN (Lücken in Y-Richtung füllen) ---
    if isfield(params, 'closeHeight') && params.closeHeight > 1
        % Baut einen vertikalen "Balken" (Höhe = closeHeight, Breite = 1)
        se_vert = strel('rectangle', [params.closeHeight, 1]); 
        B_before = imopen(B_before, se_vert);
    end
    % ---------------------------------------------------------------

    % Fallback, falls der Parameter fehlt
    if isfield(params, 'closeWidth')
        w = params.closeWidth; 
    else
        w = 1; 
    end

    % --- KORREKTUR: Morphologisches ÖFFNEN (imopen) ---
    % Löscht alle weißen Flächen (wie das Blaseninnere), die horizontal 
    % schmaler sind als 'w'. Die langen weißen Slugs bleiben erhalten.
    se = strel('rectangle', [1, w]); 
    B_after = imopen(B_before, se);

    B_after = imfill(B_after, 'holes'); 
    B = bwareaopen(B_after, params.minPixel);

    %% 3. Labeling & Vorfilterung der Objekte
    [L, num] = bwlabel(B);
    
    % Für eine Unit-Cell werden mindestens zwei Objekte (Slugs) benötigt
    if num < 2 
        return; 
    end
    
    % Einfache statistische Merkmale berechnen (Fläche und BoundingBox)
    statsBasic = regionprops(L, 'Area', 'BoundingBox');
    
    % Objekte filtern, die zu klein sind
    candidateIdx = find([statsBasic.Area] > params.minArea);
    if isempty(candidateIdx)
        return; 
    end
    
    %% 4. Dynamische Bestimmung der Kanalhöhe
    % Tritt nur im ersten Frame in Kraft (wenn noch keine Schätzung existiert)
    if isnan(channelHeightEstimate)
        % BoundingBoxes aller Kandidaten extrahieren
        candidateHeights = [statsBasic(candidateIdx).BoundingBox];
        candidateHeights = candidateHeights(4:4:end); % Das 4. Element ist die Höhe
        
        if length(candidateHeights) >= 4
            % Nimm den Median der größeren Hälfte der gefundenen Höhen
            sortedH = sort(candidateHeights);
            channelHeightEstimate = median(sortedH(ceil(end/2):end));
        else
            % KEINE Schätzwerte mehr erzwingen: Warnung ausgeben und abbrechen
            warning('Kanalhöhe konnte nicht zuverlässig bestimmt werden (zu wenig Objekte). Setze auf NaN.');
            channelHeightEstimate = NaN;
            return; % Abbruch für diesen Frame, da Filter zwingend eine Höhe brauchen
        end
    end
    
    %% 5. Detaillierte Merkmalsberechnung für gültige Kandidaten
    statsFull = regionprops(L, 'Solidity', 'Eccentricity', 'Orientation', 'Centroid');
    
    % Struktur für die exakten detektierten Slugs vorbereiten
    det = struct('cx',{},'leftX',{},'leftY',{},'rightX',{},'rightY',{},'bb',{});
    
    for k = candidateIdx
        bb = statsBasic(k).BoundingBox;
        
        %% 5.1 Plausibilitätsprüfungen (Geometrie & Lage)
        % Das Objekt muss mindestens 80% der ermittelten Kanalhöhe einnehmen
        if bb(4) < 0.90 * channelHeightEstimate
            continue; 
        end
        
        % Das Objekt muss sich grob in der vertikalen Bildmitte befinden
        if abs(statsFull(k).Centroid(2) - imgH/2) > (imgH * 0.40)
            continue; 
        end
        
        % Form-Eigenschaften (Kompaktheit, Ausdehnung, Winkel) prüfen
        sol = statsFull(k).Solidity; 
        ecc = statsFull(k).Eccentricity; 
        ori = statsFull(k).Orientation;
       
        if ~(sol >= params.minSolid && sol <= params.maxSolid && ...
             ecc >= params.minEcc && abs(ori) >= params.minAngle)
            continue; 
        end
        % Ignoriere Objekte, die den linken oder rechten Bildrand berühren (abgeschnitten sind)
        if bb(1) <= 1 || (bb(1) + bb(3)) >= imgW
            continue;
        end

        %% 5.2 Lokale Kantenbestimmung über den Perimeter
        % Begrenzungsbox auf Bildränder beschneiden, um Fehler zu vermeiden
        bx0 = max(1, floor(bb(1))); 
        by0 = max(1, floor(bb(2)));
        bx1 = min(imgW, ceil(bb(1)+bb(3)-1)); 
        by1 = min(imgH, ceil(bb(2)+bb(4)-1));
        
        if bx1 <= bx0 || by1 <= by0
            continue; 
        end
        
        % Lokalen Bildausschnitt für das aktuelle Objekt generieren
        subL = L(by0:by1, bx0:bx1);
        [rP, cP] = find(bwperim(subL == k, 8)); % Pixel des Objektumrisses finden
        if isempty(rP)
            continue; 
        end
        
                %% 5.3 Präzise Identifikation der linken und rechten Kante
        cx_local = statsFull(k).Centroid(1) - bx0 + 1; % Lokaler Mittelpunkt (X)
        spanY = max(rP) - min(rP);                     % Höhe des Perimeters
        midY = (min(rP)+max(rP))/2;                    % Vertikale Mitte des Objekts
        
        % Nur Randpixel betrachten, die sich in einem definierten Toleranzband befinden
        inBand = (rP >= midY - spanY*params.toleranceY) & (rP <= midY + spanY*params.toleranceY);
        cBand = cP(inBand); 
        rBand = rP(inBand);
        
        if isempty(cBand)
            continue; 
        end
        
        % Aufteilung in linke und rechte Randpunkte (bzgl. des Mittelpunkts)
        leftMask = cBand < cx_local; 
        rightMask = cBand >= cx_local;
        
        if ~any(leftMask) || ~any(rightMask)
            continue; 
        end
        
        % --- NEU: Umsetzung deiner Idee (Robust gegen Partikel) ---
        % Statt einfach den extremsten Punkt zu nehmen (max/min), bestimmen wir 
        % für jede Y-Höhe im Toleranzband den Randpunkt und nehmen den Median.
        
        % 1. Linke Kante
        y_left = unique(rBand(leftMask));
        x_left_profile = zeros(size(y_left));
        for i = 1:length(y_left)
            x_left_profile(i) = max(cBand(leftMask & rBand == y_left(i))); % Der rechteste Punkt pro Y-Höhe
        end
        left_x_local = round(median(x_left_profile)); % Median ignoriert Partikel-Spitzen!
        
        % 2. Rechte Kante
        y_right = unique(rBand(rightMask));
        x_right_profile = zeros(size(y_right));
        for i = 1:length(y_right)
            x_right_profile(i) = min(cBand(rightMask & rBand == y_right(i))); % Der linkeste Punkt pro Y-Höhe
        end
        right_x_local = round(median(x_right_profile));
        
        % Ergebnisse in die struct-Liste speichern
        det(end+1) = struct( ...
            'cx', statsFull(k).Centroid(1), ...
            'leftX', left_x_local + bx0 - 1, ...
            'leftY', round(midY) + by0 - 1, ...  % Y-Koordinate fest in die Mitte setzen
            'rightX', right_x_local + bx0 - 1, ...
            'rightY', round(midY) + by0 - 1, ... % Y-Koordinate fest in die Mitte setzen
            'bb', [bx0 by0 (bx1-bx0+1) (by1-by0+1)]);

    end
    
    %% 6. Auswertung der erkannten Objekte
    % Mindestens zwei gültige Slugs werden für Längen-/Abstandsmessung gebraucht
    if numel(det) < 2
        return; 
    end
    
    % Sortierung der Slugs entgegen der Laufrichtung (von rechts nach links)
    [~, sIdx] = sort([det.cx], 'descend');
    det = det(sIdx);
    
    %% 7. Berechnung von Unit-Cells (Gekoppeltes Tracking)
    for j = 1:(numel(det)-1)
        bbLeft = det(j).bb;
        bbRight = det(j+1).bb;

        % Slugs am Bildrand ignorieren (könnten abgeschnitten und verfälscht sein)
        if bbLeft(1) <= params.borderMargin || (bbRight(1) + bbRight(3)) >= (imgW - params.borderMargin)
            continue;
        end

        % --- 1. Unit Cell (UC) definieren ---
        % Die UC beginnt an der linken Kante des aktuellen Slugs j und endet an der linken Kante von j+1
        uc_start_x = det(j).leftX;
        uc_end_x = det(j+1).leftX;

        % Länge der gesamten Unit Cell
        uc_len_px = abs(uc_start_x - uc_end_x);

        % --- 2. Blase innerhalb dieser UC messen ---
        % Die Blase liegt zwischen der rechten Kante von j+1 und der linken Kante von j
        bubble_right_x = det(j+1).rightX;
        bubble_left_x = det(j).leftX;
        bubble_len_px = bubble_left_x - bubble_right_x;

        if bubble_len_px > 0 && uc_len_px > bubble_len_px
            % --- 3. Daten koppeln und speichern ---
            % Statt des Blasen-Mittelpunkts nehmen wir nun uc_start_x als Referenz-Koordinate!
            % Struktur: [X_Position, Bubble_Length, UC_Length]
            currentBubbleCentroids = [currentBubbleCentroids; uc_start_x, bubble_len_px, uc_len_px]; %#ok

            % (Optional: currentUC_px als separaten Vektor behalten, falls main_Batch ihn noch braucht)
            currentUC_px = [currentUC_px; uc_len_px]; %#ok
        end
    end

end
