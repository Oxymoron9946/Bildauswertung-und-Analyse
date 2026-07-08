function [resultsTable, statsTable] = evaluate_Physics(bubbleTracker, px2mm, fps, minFramesTracked, imgW, kanalStart_mm, binSize_mm, mean_UC_mm, L_ein_mm)
% EVALUATE_PHYSICS Berechnet Geschwindigkeiten und lokale Längen im Taylor-Flow.
%
% Diese Funktion nimmt die Rohdaten aus dem Bubble-Tracker und wandelt sie
% in physikalische Größen (mm, m/s) um. Die Ergebnisse werden örtlich in
% kleine Abschnitte (Bins) unterteilt und gemittelt, um aussagekräftige 
% Statistiken (z.B. für Diagramme) zu erzeugen.
%
% EINGABEN:
% bubbleTracker    - [N x 5] Matrix: [ID, Frame, X_Start_UC_px, BubbleLen_px, UC_Len_px]
% px2mm            - Umrechnungsfaktor von Pixel in Millimeter
% fps              - Kamera-Framerate (Bilder pro Sekunde)
% minFramesTracked - Mindestanzahl an Frames, die eine Blase getrackt werden muss (Filter)
% imgW             - Bildbreite in Pixeln (nötig, da Strömung von rechts nach links läuft)
% kanalStart_mm    - Reale Position des rechten Bildrandes im Reaktor (z.B. 0 oder 181.5 mm)
% binSize_mm       - Rastergröße für die örtliche Mittelung (z.B. 2 mm Bins)
% mean_UC_mm       - (Legacy) Globale Unit-Cell-Länge. Wird ignoriert, da wir nun lokal tracken.
% L_ein_mm         - (Optional) Berechnete hydrodynamische Einlauflänge in mm. Blasen davor werden ignoriert.
%
% BATCH (main_Batch.m): Aufruf (1) nach komplettem Video-Durchlauf je Sensitivität,
% (2) beim Early-Abort auf Teildaten nach framesToTest Frames. Filter „Blase ID 1“
% an Kameraposition 1 erfolgt im Aufrufer vor/nach dem Tracker, nicht in dieser Funktion.
%
% BLOCK 6 — Stichpunkte zur Arbeit (LaTeX: Unterabschnitt batch_evaluate_physics):
% - kanalStart_mm = Laborbuch Offset; imgW = ROI-Breite [px]; absolutePosX_mm ab rechtem Rand.
% - minFramesTracked: kurze IDs raus; mean_UC_mm Eingang wird ignoriert (lokale UC aus Spalte 5).
% - Nach resultsTable: ggf. binSize_mm an mittlere Blasenlänge anpassen; histcounts → BinCenter_mm.
% - Plateau (mittlere Bins, Median, 50-%-Schwelle, längste zusammenhängende Zone) → grpstats nur inZone.
% - UserData an statsTable: validStart, validEnd, firstMeas (Diagnose).

%% 1. Initialisierung & Abbruchbedingung
% Wenn keine Blasen gefunden wurden oder die Matrix unvollständig ist, 
% gebe leere Tabellen zurück, damit das Hauptskript nicht abstürzt.
if isempty(bubbleTracker) || size(bubbleTracker, 2) < 5
    resultsTable = table();
    statsTable = table();
    return;
end

%% 2. Vorbereitung für die Auswertungsschleife
% Leere Arrays zum Sammeln der validierten Rohdaten
all_IDs = [];
all_X_mm = [];
all_V_m_s = [];
all_BubbleLength_mm = [];
all_UnitCell_mm = [];
all_SlugLength_mm = [];
all_VoidFraction = [];

% Finde alle eindeutigen Blasen-IDs, die der Tracker vergeben hat
uniqueIDs = unique(bubbleTracker(:, 1));

%% 3. Schleife über alle einzigartigen Blasen
for i = 1:length(uniqueIDs)
    bID = uniqueIDs(i);
    
    % Finde alle Zeilen im Tracker, die zu dieser Blase gehören
    idx = find(bubbleTracker(:,1) == bID);
    
    % Rausch-Filter: Wenn die Blase nur in sehr wenigen Frames auftaucht, 
    % ist es oft ein Fehlerkennungs-Artefakt. Wir ignorieren sie.
    if length(idx) < minFramesTracked
        continue;
    end
    
    % Daten chronologisch nach Frame-Nummer (Spalte 2) sortieren
    trackData = sortrows(bubbleTracker(idx, :), 2);
    frames        = trackData(:, 2);
    x_px          = trackData(:, 3); % X-Koordinate in Pixeln
    bubble_len_px = trackData(:, 4); % Blasenlänge in Pixeln
    uc_len_px     = trackData(:, 5); % Unit-Cell-Länge in Pixeln
    
    %% 3.1 Lokale Geschwindigkeit berechnen (v = dx / dt)
    % diff() berechnet die Differenz zwischen zwei aufeinanderfolgenden Werten.
    % WICHTIG: Negatives Vorzeichen! Da die Strömung von rechts (hoher X-Pixelwert)
    % nach links (niedriger X-Pixelwert) verläuft, wäre dx negativ. 
    % Das Minus dreht es um, damit die Geschwindigkeit positiv wird.
    dx_px = -diff(x_px);
    dframes = diff(frames);
    
    % v = Weg (dx_px * px2mm) geteilt durch Zeit (dframes / fps)
    v_mm_s = (dx_px * px2mm) ./ (dframes / fps); 
    v_m_s = v_mm_s / 1000; % Umrechnung von mm/s in m/s
    
    %% 3.2 Zugehörige Längen interpolieren
    % Da die Geschwindigkeit aus der *Differenz* zwischen zwei Frames berechnet wurde, 
    % ordnen wir diesen Wert zeitlich genau der *Mitte* zwischen diesen beiden Frames zu.
    mid_x_px          = (x_px(1:end-1) + x_px(2:end)) / 2;
    mid_bubble_len_px = (bubble_len_px(1:end-1) + bubble_len_px(2:end)) / 2;
    mid_uc_len_px     = (uc_len_px(1:end-1) + uc_len_px(2:end)) / 2;
    
    % Örtliche Zuordnung auf die Mitte der Blase verschieben.
    % x_px ist der Start der Blase (rechte Kante, da Strömung von rechts nach links).
    % Um die Mitte der Blase zu erhalten, ziehen wir die halbe Blasenlänge ab.
    mid_x_px = mid_x_px - (mid_bubble_len_px / 2);
    
    % Filter gegen physikalisch unmögliche Ausreißer beim Tracking
    % (z.B. wenn der Tracker kurzzeitig eine falsche Blase anspringt)
    valid = (v_m_s > 0) & (v_m_s < 5); % Max 5 m/s erlaubt
    if sum(valid) == 0
        continue;
    end
    
    %% 3.3 Neue lokale Längen berechnen (in mm umwandeln)
    bubble_len_mm = mid_bubble_len_px(valid) * px2mm;
    uc_len_mm     = mid_uc_len_px(valid) * px2mm;
    
    % Die Länge des Flüssigkeits-Slugs ist der Rest der Unit-Cell
    slug_len_mm   = uc_len_mm - bubble_len_mm;
    
    % Void Fraction = Anteil des Gases an der Gesamt-Unit-Cell (0 bis 1)
    void_frac     = bubble_len_mm ./ uc_len_mm;
    
    % Validierte Ergebnisse für diese Blase in die großen Sammel-Arrays anhängen
    all_IDs             = [all_IDs; repmat(bID, sum(valid), 1)];
    all_X_mm            = [all_X_mm; mid_x_px(valid)];
    all_V_m_s           = [all_V_m_s; v_m_s(valid)];
    all_BubbleLength_mm = [all_BubbleLength_mm; bubble_len_mm];
    all_UnitCell_mm     = [all_UnitCell_mm; uc_len_mm];
    all_SlugLength_mm   = [all_SlugLength_mm; slug_len_mm];
    all_VoidFraction    = [all_VoidFraction; void_frac];
end

%% 4. Absolute Kanalposition im Reaktor berechnen
% Bildverarbeitung: X=0 ist links, imgW ist rechts. 
% Da das Gasgemisch am rechten Bildrand in das Bild eintritt, rechnen wir
% erst den Abstand vom rechten Rand aus:
distFromRight_mm = (imgW - all_X_mm) * px2mm;

% Danach addieren wir diesen Abstand zum Offset der Kamera (kanalStart_mm)
absolutePosX_mm = kanalStart_mm + distFromRight_mm;

% Blasen filtern, die innerhalb der Einlauflänge liegen
if nargin >= 9 && ~isnan(L_ein_mm) && L_ein_mm > 0
    valid_einlauf = absolutePosX_mm >= L_ein_mm;
    
    all_IDs = all_IDs(valid_einlauf);
    absolutePosX_mm = absolutePosX_mm(valid_einlauf);
    all_V_m_s = all_V_m_s(valid_einlauf);
    all_BubbleLength_mm = all_BubbleLength_mm(valid_einlauf);
    all_UnitCell_mm = all_UnitCell_mm(valid_einlauf);
    all_SlugLength_mm = all_SlugLength_mm(valid_einlauf);
    all_VoidFraction = all_VoidFraction(valid_einlauf);
end

% Alles in einer übersichtlichen Tabelle ("Rohdaten") speichern
resultsTable = table(all_IDs, absolutePosX_mm, all_V_m_s, ...
    all_BubbleLength_mm, all_UnitCell_mm, all_SlugLength_mm, all_VoidFraction, ...
    'VariableNames', {'BubbleID', 'Position_X_mm', 'Speed_m_s', ...
    'BubbleLength_mm', 'UnitCellLength_mm', 'SlugLength_mm', 'VoidFraction'});

% Wenn am Ende der Schleife alle Blasen aussortiert wurden, abbrechen
if isempty(resultsTable)
    statsTable = table();
    return;
end

%% 5. Statistisches Binning (Ortsaufgelöste Rasterung)
% Um glatte Graphen zu bekommen, unterteilen wir die X-Achse in "Kästchen" (Bins).
% Wir prüfen zuerst, ob der gewählte Bin (z.B. 2mm) nicht kleiner ist als eine 
% halbe Blase. Falls ja, vergrößern wir den Bin dynamisch, um genug Datenpunkte zu fassen.
meanBubbleLength_mm = mean(all_BubbleLength_mm);
if binSize_mm < meanBubbleLength_mm
    binSize_mm = ceil(meanBubbleLength_mm * 2) / 2;
end

% Raster-Grenzen (Edges) definieren
xMin = floor(min(absolutePosX_mm)/binSize_mm) * binSize_mm;
xMax = ceil(max(absolutePosX_mm)/binSize_mm) * binSize_mm;
edges = xMin:binSize_mm:xMax;

% Datenpunkte in Bins einsortieren (histcounts)
[binCount, ~, binIdx] = histcounts(absolutePosX_mm, edges);

% Den Mittelpunkt jedes Bins berechnen und den Rohdaten zuordnen
binCenter = edges(1:end-1) + binSize_mm/2;
resultsTable.BinCenter_mm = binCenter(binIdx)';

%% 6. Gültige Messzone (Plateau) identifizieren
% Am Bildrand fliegen Blasen ins Bild hinein oder hinaus, was Trackingfehler verursacht.
% Wir suchen hier nach der "stabilen Zone", in der konstant viele Blasen (binCount) gemessen wurden.
nBins = numel(binCount);
if nBins >= 3
    % Betrachte nur die mittleren 60% des Bildes als Referenz für das Plateau
    i0 = max(1, round(0.20*nBins));
    i1 = min(nBins, round(0.80*nBins));
    
    % Ein Bin ist gültig, wenn dort mindestens 50% der mittleren Blasenanzahl getrackt wurden
    isValid = binCount >= 0.50 * median(binCount(i0:i1));
    
    % Finde zusammenhängende gültige Bereiche
    d = diff([false isValid false]);
    starts = find(d==1);
    ends = find(d==-1)-1;
    
    if isempty(starts)
        validStart_mm = NaN;
        validEnd_mm = NaN;
    else
        % Nimm den längsten durchgehenden Bereich als gültige Messzone
        [~,k] = max(ends-starts);
        validStart_mm = edges(starts(k));
        validEnd_mm = edges(ends(k)+1);
    end
else
    validStart_mm = NaN;
    validEnd_mm = NaN;
end

% Logische Maske: Welche Rohdaten liegen im sicheren Plateau?
inZone = (absolutePosX_mm >= validStart_mm) & (absolutePosX_mm <= validEnd_mm);
if isnan(validStart_mm)
    warning('Keine stabile Messzone gefunden.');
    inZone = false(size(absolutePosX_mm));
end

%% 7. Gruppierte Statistik (Mittelwerte pro Bin)
% grpstats gruppiert alle Werte, die den gleichen 'BinCenter_mm' haben, 
% und berechnet dafür Mittelwert (mean), Standardabweichung (std) und Anzahl (numel).
% Wir geben hier nur die validierten Daten (inZone) hinein!
statsTable = grpstats(resultsTable(inZone,:), 'BinCenter_mm', ...
    {'mean','std','numel'}, 'DataVars', {'BubbleLength_mm', 'UnitCellLength_mm', 'SlugLength_mm', 'VoidFraction', 'Speed_m_s'});

%% 8. Zusätzliche Daten im Hintergrund speichern
% (Werden nicht als Tabelle ausgegeben, sind aber zur Diagnose hilfreich)
statsTable.Properties.UserData = struct( ...
    'validStart', validStart_mm, ...
    'validEnd', validEnd_mm, ...
    'firstMeas', min(absolutePosX_mm));

end