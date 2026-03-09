function [currentBubbleCentroids, channelHeightEstimate, det, currentUC_px] = detect_Bubbles(I, channelHeightEstimate, params)
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
    
    %% 2. Binarisierung & Rauschunterdrückung
    % Otsu-Methode zur Schwellenwertbildung
    B = imbinarize(I_eq, graythresh(I_eq));
    B = imfill(B, 'holes');             % Löcher innerhalb der Objekte füllen
    B = bwareaopen(B, params.minPixel); % Rauschen (kleine Pixelhaufen) entfernen
    
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
        if bb(4) < 0.80 * channelHeightEstimate
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
        
        % Extremalpunkte ermitteln (rechtester Pixel links, linkester Pixel rechts)
        left_x_local = max(cBand(leftMask));
        right_x_local = min(cBand(rightMask));
        
        % Ergebnisse in die struct-Liste speichern (Rückrechnung auf globale Bildkoordinaten)
        det(end+1) = struct( ...
            'cx', statsFull(k).Centroid(1), ...
            'leftX', left_x_local + bx0 - 1, ...
            'leftY', round(mean(rBand(cBand == left_x_local))) + by0 - 1, ...
            'rightX', right_x_local + bx0 - 1, ...
            'rightY', round(mean(rBand(cBand == right_x_local))) + by0 - 1, ...
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
    
    %% 7. Berechnung von Unit-Cells und Slug-Zentren
    for j = 1:(numel(det)-1)
        bbLeft = det(j).bb; 
        bbRight = det(j+1).bb;
        
        % Slugs am Bildrand ignorieren (könnten abgeschnitten und verfälscht sein)
        if bbLeft(1) <= params.borderMargin || (bbRight(1) + bbRight(3)) >= (imgW - params.borderMargin)
            continue; 
        end
        
        % Kanten für die Messung extrahieren:
        % det(j) ist die linke Grenze der Messstrecke, det(j+1) die rechte
        x_e = det(j+1).rightX; 
        x_s = det(j).leftX;    
        len_px = x_s - x_e; % Abstand zwischen rechter und linker Kante (Slug-Länge)
        
        if len_px > 0
            % X-Mittelpunkt und Länge der Blase speichern
            mid_x = (x_e + x_s) / 2;
            currentBubbleCentroids = [currentBubbleCentroids; mid_x, len_px]; %#ok<AGROW>
            
            % Unit Cell: Distanz zwischen den linken Kanten von Slug j und Slug j+1
            currentUC_px = [currentUC_px; abs(det(j).leftX - det(j+1).leftX)]; %#ok<AGROW>
        end
    end
end
