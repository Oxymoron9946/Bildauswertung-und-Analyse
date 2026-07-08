function [currentBubbleCentroids, channelState, det, currentUC_px, B_before, B_after, seeds] = detect_Bubbles(I, channelState, params)
% DETECT_BUBBLES Erkennt Flüssigkeits-Slugs und misst Unit-Cells im Taylor-Flow.
%
% EINGABEN:
%   I            - Graustufenbild (bereits auf die Region of Interest zugeschnitten)
%   channelState - Frameübergreifender Zustand der Kanalgeometrie (Struct, siehe initChannelState)
%   params       - Struktur mit Filter- und Toleranzparametern
%
% AUSGABEN:
%   currentBubbleCentroids - [N x 3] Matrix: [UC_Start_X, Bubble_Length_px, UC_Length_px]
%   channelState           - Aktualisierter Kanalzustand (inkl. heightEstimate, gesperrte Randkurven)
%   det                    - Struct mit den genauen Kantenkoordinaten der detektierten Blasen
%   currentUC_px           - Vektor mit den Längen der Unit-Cells in Pixeln
%   B_before               - Binärbild VOR den morphologischen Operationen (zur Diagnose)
%   B_after                - Binärbild NACH den morphologischen Operationen (zur Diagnose)
%
% BATCH / EINZEL (main_Batch.m, main_einzel.m):
%   I = Graustufen-ROI eines Frames (im Batch i. d. R. volle Bildfläche).
%   channelState wird frameübergreifend durchgereicht; Kanalränder werden in den ersten
%   initFramesTarget Frames robust geschätzt und danach fest verwendet.
%   params: u. a. sens (adaptthresh), closeHeight/closeWidth (imclose), minPixel,
%   minArea, borderMargin — gesetzt im Hauptskript, identische Logik Batch/Einzel.
%
% PIPELINE-ÜBERBLICK (entspricht LaTeX „Blasen- und Slug-Erkennung“):
%   (1–2) Kontrast (CLAHE) + Median → adaptives Schwellen (sens) → B_before + Morphologie
%   (3)   Kanalhintergrund als größte schwarze Region → obere/untere Randkurve → Mittellinie
%   (3ff) Mittellinien-Kanten (5px-Band) → Raycasting-Typ pro Kante → Randkanten streichen
%   (3ff) Globale Alternanz-Korrektur (Taylor 1/2) → Slug-/Blasen-Seeds
%   (4)   Region Growing (Marker+Maske+imreconstruct) → B_after (Blasen schwarz)
%   (5–6) Labeling, mindestens 2 Slugs, regionprops-Filter, ggf. Kanalhöhe aus BoundingBoxes
%   (7–8) Blasen auf Mittellinie in B_after → det → UC-Paare → currentBubbleCentroids / currentUC_px

    %% 1. Initialisierung & Bildvorbereitung
    [imgH, imgW] = size(I);
    channelState = initChannelState(channelState);
    currentBubbleCentroids = [];
    currentUC_px = []; 
    det = struct('cx', {}, 'leftX', {}, 'leftY', {}, 'rightX', {}, 'rightY', {}, 'bb', {}); % Standard-Rückgabe, falls in diesem Frame nichts gefunden wird
    
    % Kontrastverbesserung (CLAHE): Macht dunkle Bildbereiche heller und umgekehrt.
    % Extrem wichtig, damit die Ausleuchtung im gesamten Kanal gleichmäßig ist.
    I_eq = adapthisteq(I, 'NumTiles', [4 8], 'ClipLimit', 0.01);
    
    % Median-Filter (Glätten): Entfernt winzige "Salz & Pfeffer"-Artefakte an den 
    % Kanten der Blasen, bevor binarisiert wird. Macht die Kantenfindung robuster.
    I_eq = medfilt2(I_eq, [3 3]); 
    
    %% 2. Binarisierung & Rauschunterdrückung
    % Sensitivität abfragen (Standard: 0.5, falls im Hauptskript nicht definiert)
    if isfield(params, 'sens'), s = params.sens; else, s = 0.5; end
    
    % Adaptive Thresholding: Neighborhood immer auf halbe Bildhöhe setzen
    nbSize = floor(size(I_eq, 1) / 2);
    
    % MATLAB verlangt für adaptthresh zwingend ungerade Zahlen
    if mod(nbSize, 2) == 0
        nbSize = nbSize - 1; 
    end
    
    % Erstelle die lokale Schwellenwert-Matrix
    T = adaptthresh(I_eq, s, 'ForegroundPolarity', 'bright', 'NeighborhoodSize', [nbSize nbSize]);
    
    % Binarisiere das Bild anhand dieser genauen Matrix (Schwarz-Weiß-Bild)
    B_before = imbinarize(I_eq, T);
    
    % Morphologisches Schließen (imclose), um kleine Lücken in den Kanten zu füllen
    % Da die Blasen in B_before schwarz (0) sind, müssen wir das Bild für imclose
    % invertieren (~), die Risse in den schwarzen Objekten schließen, und dann 
    % wieder zurück-invertieren.
    if isfield(params, 'closeHeight') && params.closeHeight > 1
        se_vert = strel('rectangle', [params.closeHeight, 1]); 
        B_before = ~imclose(~B_before, se_vert); 
    end
    if isfield(params, 'closeWidth') && params.closeWidth > 1
        se_horz = strel('rectangle', [1, params.closeWidth]); 
        B_before = ~imclose(~B_before, se_horz); 
    end
    
    %% 3. Kanalrandmodell (Initialisierung über mehrere Frames, danach fest gesperrt)
    seeds = struct('slug_cx', [], 'slug_cy', [], 'bub_cx', [], 'bub_cy', [], 'check_lines_x', [], ...
                   'top_points_x', [], 'top_points_y', [], 'bot_points_x', [], 'bot_points_y', []);

    if channelState.locked
        y_top_line = channelState.y_top_line;
        y_bot_line = channelState.y_bot_line;
        y_mid_line = channelState.y_mid_line;
        [seeds.top_points_x, seeds.top_points_y, seeds.bot_points_x, seeds.bot_points_y] = ...
            supportPointsFromLines(channelState.x_support, y_top_line, y_bot_line);
    else
        [raw_top_x, raw_top_y, raw_bot_x, raw_bot_y] = extractRawChannelEdges(B_before, imgW, imgH);

        if isempty(raw_top_x)
            y_top_line = ones(1, imgW);
            y_bot_line = imgH * ones(1, imgW);
        else
            seeds.top_points_x = raw_top_x;
            seeds.top_points_y = raw_top_y;
            seeds.bot_points_x = raw_bot_x;
            seeds.bot_points_y = raw_bot_y;

            if isempty(channelState.x_support)
                channelState.x_support = raw_top_x;
            end

            top_on_support = interp1(raw_top_x, raw_top_y, channelState.x_support, 'linear', NaN);
            bot_on_support = interp1(raw_bot_x, raw_bot_y, channelState.x_support, 'linear', NaN);

            minValid = max(3, round(0.3 * numel(channelState.x_support)));
            nValid = sum(~isnan(top_on_support) & ~isnan(bot_on_support));
            if nValid >= minValid
                channelState.samplesTop = [channelState.samplesTop; top_on_support]; %#ok<AGROW>
                channelState.samplesBot = [channelState.samplesBot; bot_on_support]; %#ok<AGROW>
                channelState.frameCount = channelState.frameCount + 1;
            end

            if channelState.frameCount >= channelState.initFramesTarget
                channelState = buildLockedChannelModel(channelState, imgW, imgH);
                y_top_line = channelState.y_top_line;
                y_bot_line = channelState.y_bot_line;
                y_mid_line = channelState.y_mid_line;
                [seeds.top_points_x, seeds.top_points_y, seeds.bot_points_x, seeds.bot_points_y] = ...
                    supportPointsFromLines(channelState.x_support, y_top_line, y_bot_line);
            elseif channelState.initAttempts > 2 * channelState.initFramesTarget
                [y_top_line, y_bot_line, seeds] = detectChannelEdgesSingleFrame(seeds, imgW, imgH);
                channelState = buildLockedChannelModel(channelState, imgW, imgH, y_top_line, y_bot_line);
                y_mid_line = channelState.y_mid_line;
            elseif channelState.frameCount >= 1
                top_prov = median(channelState.samplesTop, 1, 'omitnan');
                bot_prov = median(channelState.samplesBot, 1, 'omitnan');
                y_top_line = interp1(channelState.x_support, top_prov, 1:imgW, 'pchip', 'extrap');
                y_bot_line = interp1(channelState.x_support, bot_prov, 1:imgW, 'pchip', 'extrap');
            else
                y_top_line = interp1(raw_top_x, raw_top_y, 1:imgW, 'pchip', 'extrap');
                y_bot_line = interp1(raw_bot_x, raw_bot_y, 1:imgW, 'pchip', 'extrap');
            end
        end

        if ~exist('y_mid_line', 'var')
            y_top_line = max(1, min(imgH, y_top_line));
            y_bot_line = max(1, min(imgH, y_bot_line));
            y_mid_line = (y_top_line + y_bot_line) / 2;
        end
    end

    % Werte auf den gültigen Bildbereich begrenzen (verhindert Index-Fehler durch Extrapolation)
    y_top_line = max(1, min(imgH, y_top_line));
    y_bot_line = max(1, min(imgH, y_bot_line));
    y_mid_line = (y_top_line + y_bot_line) / 2;
    
    % --- B_clean für Raycasting ---
    % Entferne winzige schwarze Staubkörner (Rauschen) in den weißen Slugs,
    % ohne die Kappen der Blasen zu zerstören.
    B_clean = ~bwareaopen(~B_before, 15);
    
    % --- NEU: Kanten auf einem 5-Pixel-Band um die Mittellinie finden ---
    % 1D-Profil extrahieren (1 = Schwarz/Kante, 0 = Weiß/Slug)
    midline_profile = zeros(1, imgW);
    for x = 1:imgW
        y = round(y_mid_line(x));
        y_start = max(1, y - 2);
        y_end   = min(imgH, y + 2);
        % Wenn irgendein Pixel in diesem 5er-Band schwarz (0) ist, werten wir es als Kante
        midline_profile(x) = any(B_clean(y_start:y_end, x) == 0); 
    end
    
    % Zusammenhängende schwarze Linienabschnitte finden
    [L_edges, num_edges] = bwlabel(midline_profile);
    
    % Alte Seeds aus der groben Vorfilterung löschen und neue Felder vorbereiten
    seeds.slug_cx = []; seeds.slug_cy = [];
    seeds.bub_cx = []; seeds.bub_cy = [];
    seeds.tie_cx = []; seeds.tie_cy = [];
    seeds.center_cx = []; seeds.center_cy = [];
    seeds.ray_x = []; seeds.ray_y0 = []; seeds.ray_y1 = [];
    seeds.mid_line_y = y_mid_line;
    seeds.y_top_line = y_top_line;
    seeds.y_bot_line = y_bot_line;
    
    edges = struct('x', {}, 'y', {}, 'type', {});
    det_slugs = struct('cx', {}, 'leftX', {}, 'leftY', {}, 'rightX', {}, 'rightY', {}, 'bb', {});
    
    for i = 1:num_edges
        edge_x_coords = find(L_edges == i);
        
        % Der exakte Mittelpunkt der dicken schwarzen Kante auf der Mittellinie
        x_edge = round(mean(edge_x_coords));
        y_edge = round(y_mid_line(x_edge));
        
        % --- 1. Echte Startpunkte finden (raus aus der dicken schwarzen Kante) ---
        x_left_start = x_edge;
        while x_left_start > 1 && B_clean(round(y_mid_line(x_left_start)), x_left_start) == 0
            x_left_start = x_left_start - 1;
        end
        
        x_right_start = x_edge;
        while x_right_start < imgW && B_clean(round(y_mid_line(x_right_start)), x_right_start) == 0
            x_right_start = x_right_start + 1;
        end
        
        % --- 2. Maximale Suchdistanz bestimmen (bis zur nächsten Kante) ---
        dist_left = 0;
        x_search = x_left_start;
        while x_search > 1 && B_clean(round(y_mid_line(x_search)), x_search) == 1
            x_search = x_search - 1;
            dist_left = dist_left + 1;
        end
        
        dist_right = 0;
        x_search = x_right_start;
        while x_search < imgW && B_clean(round(y_mid_line(x_search)), x_search) == 1
            x_search = x_search + 1;
            dist_right = dist_right + 1;
        end
        
        % Begrenze auf maximal 20 Pixel oder 80% der Distanz zum nächsten Rand
        max_search = min([floor(dist_left * 0.8), floor(dist_right * 0.8), 20]);
        if max_search < 2
            max_search = 2; % Mindestens 2 Pixel versuchen
        end
        
        % --- 3. Raycasting und Voting ---
        vote_left_shorter = 0;
        vote_right_shorter = 0;
        
        for step = 1:max_search
            x_L = max(1, x_left_start - step);
            x_R = min(imgW, x_right_start + step);
            
            y_mid_L = round(y_mid_line(x_L));
            y_mid_R = round(y_mid_line(x_R));
            
            % Raycast Links (nach oben und unten bis zum ersten schwarzen Pixel)
            y_up_L = y_mid_L;
            while y_up_L > 1 && B_clean(y_up_L, x_L) == 1, y_up_L = y_up_L - 1; end
            y_down_L = y_mid_L;
            while y_down_L < imgH && B_clean(y_down_L, x_L) == 1, y_down_L = y_down_L + 1; end
            dist_vert_L = y_down_L - y_up_L;
            
            % Raycast Rechts (nach oben und unten bis zum ersten schwarzen Pixel)
            y_up_R = y_mid_R;
            while y_up_R > 1 && B_clean(y_up_R, x_R) == 1, y_up_R = y_up_R - 1; end
            y_down_R = y_mid_R;
            while y_down_R < imgH && B_clean(y_down_R, x_R) == 1, y_down_R = y_down_R + 1; end
            dist_vert_R = y_down_R - y_up_R;
            
            % Visualisierung speichern (Magenta Linien für den Export)
            seeds.ray_x(end+1) = x_L; seeds.ray_y0(end+1) = y_up_L; seeds.ray_y1(end+1) = y_down_L;
            seeds.ray_x(end+1) = x_R; seeds.ray_y0(end+1) = y_up_R; seeds.ray_y1(end+1) = y_down_R;
            
            % Voting: Auf welcher Seite ist der Weg kürzer?
            if dist_vert_R < dist_vert_L
                % Rechts ist kürzer -> Krümmung '(' -> Linke Kante einer Blase (Grün)
                vote_right_shorter = vote_right_shorter + 1;
            elseif dist_vert_L < dist_vert_R
                % Links ist kürzer -> Krümmung ')' -> Linke Kante eines Slugs (Rot)
                vote_left_shorter = vote_left_shorter + 1;
            end
        end
        
        % --- 4. Entscheidung ---
        if vote_right_shorter > vote_left_shorter
            edges(end+1) = struct('x', x_edge, 'y', y_edge, 'type', 1);
        elseif vote_left_shorter > vote_right_shorter
            edges(end+1) = struct('x', x_edge, 'y', y_edge, 'type', 2);
        else
            edges(end+1) = struct('x', x_edge, 'y', y_edge, 'type', 0);
        end
    end
    
    % Kanten von links nach rechts sortieren
    if ~isempty(edges)
        [~, sortIdx] = sort([edges.x]);
        edges = edges(sortIdx);
        
        % NEU: Entferne die äußerste linke und äußerste rechte Kante komplett, 
        % da diese oft zu nah am ROI-Rand liegen und Fehler (Hellblau) verursachen.
        if length(edges) >= 3
            edges = edges(2:end-1);
        else
            edges = []; % Zu wenig Kanten übrig für eine sinnvolle Auswertung
        end
    end
    
    % --- LOKALE LOGISCHE ZUORDNUNG ALLER KANTEN ---
    % Im Taylor-Flow müssen die Kanten strikt alternieren: Grün(1), Rot(2), Grün(1), Rot(2)...
    % Wenn Störkanten auftreten, filtern wir diese basierend auf dem typischen Abstand
    % zwischen benachbarten Kanten heraus (Rhythmus-Check).
    
    if ~isempty(edges)
        % 1. LOKALE FEHLERBEHEBUNG DURCHFÜHREN
        i = 1;
        while i <= length(edges)
            % Behandle Kanten, deren Typ 0 (unentschieden) ist:
            if edges(i).type == 0
                if i > 1
                    edges(i).type = 3 - edges(i-1).type; % 3 - 1 = 2, 3 - 2 = 1
                elseif i < length(edges) && edges(i+1).type ~= 0
                    edges(i).type = 3 - edges(i+1).type;
                else
                    edges(i).type = 1;
                end
                % Markiere als korrigiert (Cyan)
                seeds.tie_cx(end+1) = edges(i).x;
                seeds.tie_cy(end+1) = edges(i).y;
            end

            % Konflikt gefunden: Zwei gleiche Kantentypen nebeneinander
            if i < length(edges) && edges(i).type == edges(i+1).type
                
                % Berechne die Mediane ERST HIER (nur wenn wirklich ein Konflikt auftritt)
                dist_1_to_2 = [];
                dist_2_to_1 = [];
                for k = 1:(length(edges)-1)
                    if edges(k).type == 1 && edges(k+1).type == 2
                        dist_1_to_2(end+1) = edges(k+1).x - edges(k).x;
                    elseif edges(k).type == 2 && edges(k+1).type == 1
                        dist_2_to_1(end+1) = edges(k+1).x - edges(k).x;
                    end
                end
                
                if isempty(dist_1_to_2), med_1_2 = 50; else, med_1_2 = median(dist_1_to_2); end
                if isempty(dist_2_to_1), med_2_1 = 50; else, med_2_1 = median(dist_2_to_1); end
                
                type = edges(i).type;
                
                % Fehler-Scores für beide Lösch-Szenarien
                error_drop_i = 0;
                error_drop_next = 0;
                
                % Teste Abstand zum linken Nachbarn (falls vorhanden)
                if i > 1
                    if type == 1
                        expected_dist = med_2_1; 
                    else
                        expected_dist = med_1_2; 
                    end
                    
                    error_drop_i = error_drop_i + abs((edges(i+1).x - edges(i-1).x) - expected_dist);
                    error_drop_next = error_drop_next + abs((edges(i).x - edges(i-1).x) - expected_dist);
                end
                
                % Teste Abstand zum rechten Nachbarn (falls vorhanden)
                if i+2 <= length(edges)
                    if type == 1
                        expected_dist = med_1_2; 
                    else
                        expected_dist = med_2_1; 
                    end
                    
                    error_drop_i = error_drop_i + abs((edges(i+2).x - edges(i+1).x) - expected_dist);
                    error_drop_next = error_drop_next + abs((edges(i+2).x - edges(i).x) - expected_dist);
                end
                
                % ENTSCHEIDUNG
                if error_drop_i < error_drop_next
                    seeds.tie_cx(end+1) = edges(i).x; 
                    seeds.tie_cy(end+1) = edges(i).y;
                    edges(i) = []; % Kante i löschen
                else
                    seeds.tie_cx(end+1) = edges(i+1).x; 
                    seeds.tie_cy(end+1) = edges(i+1).y;
                    edges(i+1) = []; % Kante i+1 löschen
                end
                
                % WICHTIG: i nicht hochzählen!
            else
                % Alles in Ordnung, weiter
                i = i + 1;
            end
        end

        % In die finalen Seed-Arrays einsortieren (für Region Growing und Visualisierung)
        for i = 1:length(edges)
            if edges(i).type == 1
                seeds.bub_cx(end+1) = edges(i).x;
                seeds.bub_cy(end+1) = edges(i).y;
            elseif edges(i).type == 2
                seeds.slug_cx(end+1) = edges(i).x;
                seeds.slug_cy(end+1) = edges(i).y;
            end
        end
    end
    
    %% 4. REGION GROWING (Blasen schwarz füllen)
    % Wir setzen den Seed in den weißen Bereich rechts neben einem grünen Punkt (Blase)
    % und links neben einem roten Punkt.
    Marker = false(size(B_before));
    
    % 1. Seeds rechts von grünen Punkten
    for i = 1:length(seeds.bub_cx)
        x_green = seeds.bub_cx(i);
        
        % Suche nach rechts auf der Mittellinie den ersten weißen Pixel
        x_seed = x_green;
        while x_seed < imgW && B_clean(round(y_mid_line(x_seed)), x_seed) == 0
            x_seed = x_seed + 1;
        end
        
        % Wenn wir einen weißen Pixel gefunden haben, setze dort den Marker
        if x_seed < imgW
            y_seed = round(y_mid_line(x_seed));
            Marker(y_seed, x_seed) = true;
        end
    end
    
    % 2. Seeds links von roten Punkten
    for i = 1:length(seeds.slug_cx)
        x_red = seeds.slug_cx(i);
        
        % Suche nach links auf der Mittellinie den ersten weißen Pixel
        x_seed = x_red;
        while x_seed > 1 && B_clean(round(y_mid_line(x_seed)), x_seed) == 0
            x_seed = x_seed - 1;
        end
        
        if x_seed > 1
            y_seed = round(y_mid_line(x_seed));
            Marker(y_seed, x_seed) = true;
        end
    end
    
    % Maske ist das ursprüngliche Binärbild (Slugs und Blasen sind weiß)
    Mask = B_before;
    
    % Harte Grenzen einziehen: Das Ausdehnen darf in X-Richtung nicht über 
    % die grünen und roten Punkte hinausgehen. Wir setzen diese Spalten in der Maske auf Schwarz.
    for i = 1:length(seeds.bub_cx)
        Mask(:, seeds.bub_cx(i)) = false;
    end
    for i = 1:length(seeds.slug_cx)
        Mask(:, seeds.slug_cx(i)) = false;
    end
    
    % Finde alle weißen Bereiche, die zu den Blasen gehören
    FilledBubbles = imreconstruct(Marker, Mask);
    
    % Blasen schwarz färben, Slugs weiß lassen
    B_after = B_before & ~FilledBubbles;
    
    % Letzte Säuberung der Slugs (Staub entfernen)
    B_after = bwareaopen(B_after, params.minPixel);
    B = B_after; % B für die nachfolgende Auswertung setzen
    
    % Speichere Bilder und Masken für den Export in der Arbeit
    seeds.I_eq = I_eq;
    seeds.B_clean = B_clean;
    seeds.Marker = Marker;
    seeds.Mask = Mask;
    
    %% 5. Labeling & Vorfilterung der Objekte (für Kanalhöhe)
    % bwlabel gibt jedem getrennten weißen Objekt eine eigene Nummer (1, 2, 3...)
    [L, num] = bwlabel(B);
    
    % Für eine Unit-Cell (Slug + Blase) werden mindestens zwei Slugs im Bild benötigt.
    % Gibt es weniger, können wir nichts messen -> Abbruch für diesen Frame.
    if num < 2 
        return; 
    end
    
    % Einfache Merkmale (Fläche, BoundingBox und Formfaktoren) für alle Objekte berechnen
    statsBasic = regionprops(L, 'Area', 'BoundingBox', 'Solidity', 'Eccentricity', 'Orientation');
    
    % Filtern: Nur Objekte betrachten, die groß genug sind UND alle Form-Kriterien erfüllen
    candidateIdx = find([statsBasic.Area] > params.minArea);
    
    if isempty(candidateIdx)
        return;
    end
    
    %% 6. Dynamische Bestimmung der Kanalhöhe
    % Fallback, falls heightEstimate noch nicht aus dem Kanalmodell gesetzt wurde.
    if isnan(channelState.heightEstimate)
        % BoundingBoxes aller Kandidaten extrahieren. Format: [X, Y, Breite, Höhe]
        candidateHeights = [statsBasic(candidateIdx).BoundingBox];
        candidateHeights = candidateHeights(4:4:end); % Greife nur auf jedes 4. Element (die Höhe) zu
        
        if length(candidateHeights) >= 4
            % Sortieren und den Median der größeren Hälfte nehmen, 
            % um flache Störobjekte zu ignorieren
            sortedH = sort(candidateHeights);
            channelState.heightEstimate = median(sortedH(ceil(end/2):end));
        else
            % Nicht genug Daten im ersten Frame -> Warnung, aber noch keine Werte setzen.
            warning('Kanalhöhe konnte nicht zuverlässig bestimmt werden (zu wenig Objekte). Setze auf NaN.');
            channelState.heightEstimate = NaN;
            return; % Frame abbrechen. Wir versuchen es im nächsten Frame erneut.
        end
    end
    
    %% 7. BLASEN AUS GEFÜLLTEM BILD EXTRAHIEREN
    % Das Bild B_after ist nun perfekt gefüllt (Blasen sind schwarz, Slugs weiß).
    % Wir gehen auf einem 5-Pixel-Band um die Mittellinie entlang und messen die schwarzen Abschnitte.
    
    midline_after = zeros(1, imgW);
    for x = 1:imgW
        y = round(y_mid_line(x));
        y_start = max(1, y - 2);
        y_end   = min(imgH, y + 2);
        % 1 wenn Blase (schwarz) in diesem Band gefunden wird
        midline_after(x) = any(B_after(y_start:y_end, x) == 0); 
    end
    
    % Zusammenhängende schwarze Linienabschnitte (Blasen) finden
    [L_bubbles, num_bubbles] = bwlabel(midline_after);
    
    for i = 1:num_bubbles
        bub_x_coords = find(L_bubbles == i);
        
        if length(bub_x_coords) > 5 % Mindestlänge für eine Blase
            leftX = min(bub_x_coords);
            rightX = max(bub_x_coords);
            
            % NEU: Blase ignorieren, wenn sie den linken oder rechten Bildrand berührt
            % (Es muss mindestens 1 weißer Pixel davor und danach sein)
            if leftX <= 1 || rightX >= imgW
                continue;
            end
            
            bub_cx = (leftX + rightX) / 2;
            
            % Blauen Punkt für die Mitte speichern
            seeds.center_cx(end+1) = bub_cx;
            seeds.center_cy(end+1) = round(y_mid_line(round(bub_cx)));
            
            % Ungefähre BoundingBox für die Visualisierung/Tracking
            % (Höhe ist hier nicht so wichtig, wir nehmen einfach imgH/2)
            bub_bb = [leftX, 1, rightX - leftX, imgH];
            
            det(end+1) = struct( ...
                'cx', bub_cx, ...
                'leftX', leftX, ...
                'leftY', round(y_mid_line(leftX)), ...
                'rightX', rightX, ...
                'rightY', round(y_mid_line(rightX)), ...
                'bb', bub_bb);
        end
    end
    
    % Sortiere die Blasen von rechts nach links (da die Strömung so verläuft)
    if ~isempty(det)
        [~, sIdx] = sort([det.cx], 'descend');
        det = det(sIdx);
    end
    
    % Wenn keine gültigen Blasen gefunden wurden
    if numel(det) < 1
        return;
    end
    
    %% 8. Berechnung von Unit-Cells (Gekoppeltes Tracking)
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
        % det enthält die Blasen; UC von linker Kante einer Blase zur linken Kante der nächsten
        uc_start_x = det(j).leftX;
        uc_end_x   = det(j+1).leftX;
        uc_len_px  = abs(uc_start_x - uc_end_x);
        
        % --- 2. Blasenlänge = Breite des det-Objekts ---
        bubble_len_px = det(j+1).rightX - det(j+1).leftX;
        
        % --- 3. Daten speichern ---
        % Wenn die Werte physikalisch Sinn machen, speichern wir sie für den Tracker.
        % Struktur für Tracker: [Mittelpunkt_der_Blase, Blasenlänge, UnitCell_Länge]
        if bubble_len_px > 0 && uc_len_px > bubble_len_px
            currentBubbleCentroids = [currentBubbleCentroids; det(j).cx, bubble_len_px, uc_len_px]; %#ok
            currentUC_px = [currentUC_px; uc_len_px]; %#ok
        end
    end
end

%% --- Lokale Hilfsfunktionen: Kanalgeometrie ---

function channelState = initChannelState(channelState)
    defaults = struct( ...
        'locked', false, ...
        'initFramesTarget', 10, ...
        'frameCount', 0, ...
        'initAttempts', 0, ...
        'samplesTop', [], ...
        'samplesBot', [], ...
        'x_support', [], ...
        'y_top_line', [], ...
        'y_bot_line', [], ...
        'y_mid_line', [], ...
        'width_ref', [], ...
        'heightEstimate', NaN, ...
        'validTopMask', [], ...
        'validBotMask', []);
    if nargin < 1 || isempty(channelState) || ~isstruct(channelState)
        channelState = defaults;
        return;
    end
    fn = fieldnames(defaults);
    for k = 1:numel(fn)
        if ~isfield(channelState, fn{k})
            channelState.(fn{k}) = defaults.(fn{k});
        end
    end
    channelState.initAttempts = channelState.initAttempts + 1;
end

function [raw_top_x, raw_top_y, raw_bot_x, raw_bot_y] = extractRawChannelEdges(B_before, imgW, imgH)
    raw_top_x = [];
    raw_top_y = [];
    raw_bot_x = [];
    raw_bot_y = [];

    L_black = bwlabel(~B_before);
    stats_black = regionprops(L_black, 'Area', 'PixelList');
    if isempty(stats_black)
        return;
    end

    [~, max_idx] = max([stats_black.Area]);
    pixels = stats_black(max_idx).PixelList;

    step_size = 20;
    x_check = 1:step_size:imgW;
    for i = 1:numel(x_check)
        x_curr = x_check(i);
        idx = pixels(:, 1) == x_curr;
        if any(idx)
            y_vals = pixels(idx, 2);
            raw_top_x(end+1) = x_curr; %#ok<AGROW>
            raw_top_y(end+1) = min(y_vals); %#ok<AGROW>
            raw_bot_x(end+1) = x_curr; %#ok<AGROW>
            raw_bot_y(end+1) = max(y_vals); %#ok<AGROW>
        end
    end

    if isempty(raw_top_x)
        raw_top_x = 1;
        raw_top_y = 1;
        raw_bot_x = 1;
        raw_bot_y = imgH;
    end
end

function channelState = buildLockedChannelModel(channelState, imgW, imgH, y_top_line_in, y_bot_line_in)
    if nargin >= 5 && ~isempty(y_top_line_in) && ~isempty(y_bot_line_in)
        top_fixed = interp1(1:imgW, y_top_line_in, channelState.x_support, 'linear', 'extrap');
        bot_fixed = interp1(1:imgW, y_bot_line_in, channelState.x_support, 'linear', 'extrap');
        validTop = true(size(top_fixed));
        validBot = true(size(bot_fixed));
        medianWidth = median(bot_fixed - top_fixed, 'omitnan');
    else
        top_med = median(channelState.samplesTop, 1, 'omitnan');
        bot_med = median(channelState.samplesBot, 1, 'omitnan');
        width_profile = bot_med - top_med;
        medianWidth = median(width_profile, 'omitnan');
        if isnan(medianWidth) || medianWidth <= 0
            medianWidth = max(imgH * 0.1, 10);
        end

        [top_fixed, bot_fixed, validTop, validBot] = repairChannelEdgesLocally( ...
            top_med, bot_med, width_profile, medianWidth, channelState.samplesTop, channelState.samplesBot, ...
            channelState.x_support);
    end

    y_top_line = interp1(channelState.x_support, top_fixed, 1:imgW, 'pchip', 'extrap');
    y_bot_line = interp1(channelState.x_support, bot_fixed, 1:imgW, 'pchip', 'extrap');
    y_top_line = max(1, min(imgH, y_top_line));
    y_bot_line = max(1, min(imgH, y_bot_line));
    y_mid_line = (y_top_line + y_bot_line) / 2;

    channelState.y_top_line = y_top_line;
    channelState.y_bot_line = y_bot_line;
    channelState.y_mid_line = y_mid_line;
    channelState.width_ref = bot_fixed - top_fixed;
    channelState.heightEstimate = medianWidth;
    channelState.validTopMask = validTop;
    channelState.validBotMask = validBot;
    channelState.locked = true;
end

function [top_fixed, bot_fixed, validTop, validBot] = repairChannelEdgesLocally( ...
        top_med, bot_med, width_profile, medianWidth, samplesTop, samplesBot, x_support)
    n = numel(top_med);
    validTop = ~isnan(top_med);
    validBot = ~isnan(bot_med);

    widthTol = max(3, 0.08 * medianWidth);
    jumpThresh = max(3, 0.05 * medianWidth);
    curvThresh = max(2, 0.03 * medianWidth);
    stdThresh = max(2, 0.04 * medianWidth);

    topJump = localNeighborJump(top_med);
    botJump = localNeighborJump(bot_med);
    topCurv = localSecondDiff(top_med);
    botCurv = localSecondDiff(bot_med);

    if ~isempty(samplesTop) && size(samplesTop, 1) >= 2
        topStd = std(samplesTop, 0, 1, 'omitnan');
        botStd = std(samplesBot, 0, 1, 'omitnan');
        nanFracTop = mean(isnan(samplesTop), 1);
        nanFracBot = mean(isnan(samplesBot), 1);
        validTop = validTop & (topStd <= stdThresh) & (nanFracTop <= 0.5);
        validBot = validBot & (botStd <= stdThresh) & (nanFracBot <= 0.5);
    end

    badWidth = abs(width_profile - medianWidth) > widthTol;
    for i = 1:n
        if ~badWidth(i)
            continue;
        end
        scoreTop = topJump(i) + topCurv(i);
        scoreBot = botJump(i) + botCurv(i);
        if scoreTop > scoreBot
            validTop(i) = false;
        elseif scoreBot > scoreTop
            validBot(i) = false;
        else
            validTop(i) = false;
            validBot(i) = false;
        end
    end

    topJumpOnly = topJump > jumpThresh;
    botJumpOnly = botJump > jumpThresh;
    topCurvOnly = topCurv > curvThresh;
    botCurvOnly = botCurv > curvThresh;
    validTop = validTop & ~(topJumpOnly | topCurvOnly);
    validBot = validBot & ~(botJumpOnly | botCurvOnly);

    validTopMask = validTop;
    validBotMask = validBot;

    width_ref_local = localWidthReference(width_profile, medianWidth, validTop & validBot);

    top_fixed = top_med;
    bot_fixed = bot_med;
    for i = 1:n
        if ~validTopMask(i) && validBotMask(i)
            top_fixed(i) = bot_fixed(i) - width_ref_local(i);
        elseif validTopMask(i) && ~validBotMask(i)
            bot_fixed(i) = top_fixed(i) + width_ref_local(i);
        end
    end

    anchorTop = validTopMask & ~isnan(top_fixed);
    if sum(anchorTop) >= 2
        top_fixed = fillInvalidByInterpolation(x_support, top_fixed, anchorTop);
    end

    anchorBot = validBotMask & ~isnan(bot_fixed);
    if sum(anchorBot) >= 2
        bot_fixed = fillInvalidByInterpolation(x_support, bot_fixed, anchorBot);
    end

    stillBad = isnan(top_fixed) | isnan(bot_fixed);
    if any(stillBad)
        top_fixed(stillBad) = top_med(stillBad);
        bot_fixed(stillBad) = bot_med(stillBad);
    end

    validTop = validTopMask;
    validBot = validBotMask;
end

function jumps = localNeighborJump(y)
    n = numel(y);
    jumps = zeros(1, n);
    for i = 1:n
        vals = [];
        if i > 1, vals(end+1) = y(i-1); end %#ok<AGROW>
        if i < n, vals(end+1) = y(i+1); end %#ok<AGROW>
        vals = vals(~isnan(vals));
        if ~isempty(vals) && ~isnan(y(i))
            jumps(i) = min(abs(y(i) - vals));
        end
    end
end

function curv = localSecondDiff(y)
    n = numel(y);
    curv = zeros(1, n);
    if n < 3
        return;
    end
    d2 = abs(diff(y, 2));
    curv(2:end-1) = d2;
    curv(1) = d2(1);
    curv(end) = d2(end);
    curv(isnan(curv)) = 0;
end

function width_ref_local = localWidthReference(width_profile, medianWidth, validPairMask)
    n = numel(width_profile);
    width_ref_local = medianWidth * ones(1, n);
    for i = 1:n
        idx = max(1, i-2):min(n, i+2);
        localVals = width_profile(idx);
        localVals = localVals(validPairMask(idx) & ~isnan(localVals));
        if ~isempty(localVals)
            width_ref_local(i) = median(localVals);
        end
    end
end

function y_fixed = fillInvalidByInterpolation(x, y, validMask)
    y_fixed = y;
    invalidIdx = find(~validMask & isnan(y_fixed));
    validIdx = find(validMask & ~isnan(y_fixed));
    if isempty(invalidIdx)
        return;
    end
    if numel(validIdx) < 2
        fillVal = median(y_fixed(validIdx), 'omitnan');
        if isnan(fillVal)
            fillVal = 0;
        end
        y_fixed(invalidIdx) = fillVal;
        return;
    end
    y_fixed(invalidIdx) = interp1(x(validIdx), y_fixed(validIdx), x(invalidIdx), 'pchip', 'extrap');
end

function [top_x, top_y, bot_x, bot_y] = supportPointsFromLines(x_support, y_top_line, y_bot_line)
    if isempty(x_support)
        step_size = 20;
        x_support = 1:step_size:numel(y_top_line);
    end
    top_x = x_support;
    top_y = interp1(1:numel(y_top_line), y_top_line, x_support, 'linear', 'extrap');
    bot_x = x_support;
    bot_y = interp1(1:numel(y_bot_line), y_bot_line, x_support, 'linear', 'extrap');
end

function [y_top_line, y_bot_line, seeds] = detectChannelEdgesSingleFrame(seeds, imgW, imgH)
    if numel(seeds.top_points_x) >= 3
        channel_heights = seeds.bot_points_y - seeds.top_points_y;
        median_height = median(channel_heights);
        min_allowed_height = median_height * 0.85;

        for i = 2:numel(seeds.top_points_x)
            if channel_heights(i) < min_allowed_height
                jump_top = abs(seeds.top_points_y(i) - seeds.top_points_y(i-1));
                jump_bot = abs(seeds.bot_points_y(i) - seeds.bot_points_y(i-1));
                if jump_top > jump_bot
                    seeds.top_points_y(i) = seeds.top_points_y(i-1);
                else
                    seeds.bot_points_y(i) = seeds.bot_points_y(i-1);
                end
                channel_heights(i) = seeds.bot_points_y(i) - seeds.top_points_y(i);
            end
        end

        y_top_line = interp1(seeds.top_points_x, seeds.top_points_y, 1:imgW, 'pchip', 'extrap');
        y_bot_line = interp1(seeds.bot_points_x, seeds.bot_points_y, 1:imgW, 'pchip', 'extrap');
    else
        y_top_line = ones(1, imgW);
        y_bot_line = imgH * ones(1, imgW);
    end
end