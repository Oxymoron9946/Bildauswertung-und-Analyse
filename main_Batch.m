%% Parallele Batch-Auswertung (Inkl. Metadaten- & Setup-Integration)
clc; close all; clear;

% -------------------------------------------------------------------------
% 0. PFADE ZU DEN METADATEN-DATEIEN (HIER ANPASSEN!)
% -------------------------------------------------------------------------
% Fester Pfad zu deinem aus Excel exportierten Laborbuch
laborbuchPath = 'Laborbuch.csv'; 

% -------------------------------------------------------------------------
% 1. PARAMETER & KONFIGURATION
% -------------------------------------------------------------------------
% Filter für Flüssigkeits-Slugs / Blasen (Rauschen filtern)
params.minPixel = 50;    % Mindestanzahl an Pixeln, damit etwas als Blase zählt
params.minArea = 100;    % Mindestfläche in Pixeln
params.toleranceY = 0.2; % Toleranz für Abweichungen in der Y-Achse
params.borderMargin = 2; % Pixelabstand, den Objekte vom Bildrand halten müssen

% Tracking Parameter
params.maxJumpDist_px = 50;  % Maximale Pixel, die sich eine Blase zwischen zwei Frames bewegen darf
params.minFramesTracked = 10; % Eine Blase muss mindestens in 10 Frames zu sehen sein (verhindert Geister-Tracking)

% Physik & Bildverarbeitung
params.binSize_mm = 2;       % Größe der Bins für die örtliche Mittelung
params.fps = 200;            % Standard Framerate (falls nicht auslesbar)

% Wichtige Tuning-Parameter für die Bildverarbeitung (Morphologische Operationen)
params.closeWidth = 3;       % Schließt Risse in der Blase in X-Richtung
params.closeHeight = 7;      % Schließt Risse in der Blase in Y-Richtung

% -------------------------------------------------------------------------
% 2. TABELLEN EINLESEN (Laborbuch & Setup)
% -------------------------------------------------------------------------
fprintf('--- Lade Konfigurationsdateien ---\n');

% Lese Laborbuch ein (VariableNamingRule erhält die exakten Spaltennamen wie 'CO2-Anteil')
if ~isfile(laborbuchPath)
    error('Laborbuch nicht gefunden unter: %s', laborbuchPath);
end
labTable = readtable(laborbuchPath, 'Delimiter', ';', 'VariableNamingRule', 'preserve');
fprintf('Laborbuch geladen: %d Einträge gefunden.\n', height(labTable));

fprintf('----------------------------------\n\n');

% -------------------------------------------------------------------------
% 3. BATCH-PARAMETER & ORDNERWAHL (Videos)
% -------------------------------------------------------------------------
baseDir = uigetdir('', 'Bitte den Hauptordner (z.B. "Glaskanal") auswählen');
if baseDir == 0, return; end

% Finde alle .avi Dateien im gewählten Ordner und Unterordnern
allVideoFiles = dir(fullfile(baseDir, '**', 'XSM-3520 Camera 0330_*.avi'));
if isempty(allVideoFiles)
    error('Keine passenden .avi Dateien gefunden!');
end

% --- KALIBRIERUNGEN VORBEREITEN ---
calibMap = containers.Map('KeyType', 'char', 'ValueType', 'double');
fprintf('\n--- Lese Kalibrierungen ein ---\n');
calibVideoFiles = dir(fullfile(baseDir, '**', 'Kalibrierung_*', '*.avi'));
for c = 1:length(calibVideoFiles)
    cFolder = calibVideoFiles(c).folder;
    cName = calibVideoFiles(c).name;
    % Extrahiere die Gruppe (z.B. Pos_1_Kal_1)
    tok = regexp(cFolder, '(Pos_\d+_Kal_\d+)', 'tokens');
    if ~isempty(tok)
        groupName = tok{1}{1};
        vcalib = VideoReader(fullfile(cFolder, cName));
        firstFrameCalib = readFrame(vcalib);
        if ndims(firstFrameCalib) == 3
            firstFrameCalib = rgb2gray(firstFrameCalib);
        end
        % Kalibrierungsfunktion aufrufen
        [px2mm_calib, calibSuccess] = setup_Calibration(firstFrameCalib, false);
        if calibSuccess
            calibMap(groupName) = px2mm_calib;
            fprintf('Gruppe %s: %.5f mm/px\n', groupName, px2mm_calib);
        end
    end
end
fprintf('--------------------------------\n\n');

% Messvideos von Kalibriervideos trennen
videoFiles = [];
for i = 1:length(allVideoFiles)
    if ~contains(allVideoFiles(i).folder, 'Kalibrierung_')
        videoFiles = [videoFiles; allVideoFiles(i)]; 
    end
end

% -------------------------------------------------------------------------
% 4. PARALLELE HAUPTSCHLEIFE (parfor)
% -------------------------------------------------------------------------
numTotal = length(videoFiles);
fprintf('Starte parallele Batch-Auswertung für %d Messvideos...\n', numTotal);

% Grafischen Ladebalken erstellen
wb = waitbar(0, sprintf('Starte Auswertung von %d Videos...', numTotal), 'Name', 'Batch-Fortschritt');
D = parallel.pool.DataQueue;

% Diese Funktion wird jedes Mal aufgerufen, wenn ein Worker ein Video fertig hat
afterEach(D, @(~) updateWaitbar(wb, numTotal)); 

statsCell = cell(numTotal, 1);

parfor vIdx = 1:length(videoFiles)
    videoFile = fullfile(videoFiles(vIdx).folder, videoFiles(vIdx).name);
    
    % Prüfen, zu welcher Kalibrier-Gruppe das Video gehört
    groupTok = regexp(videoFile, '(Pos_\d+_Kal_\d+)', 'tokens');
    if isempty(groupTok)
        warning('ÜBERSPRUNGEN: Video hat kein "Pos_X_Kal_Y" im Pfad: %s', videoFile);
        continue;
    end
    groupName = groupTok{1}{1};
    
    % Ordnernamen des Videos extrahieren (falls noch in einem "200fps" Ordner, gehe eine Ebene höher)
    folders = strsplit(videoFiles(vIdx).folder, filesep);
    if contains(folders{end}, 'fps', 'IgnoreCase', true)
        folderName = folders{end-1}; 
    else
        folderName = folders{end}; 
    end
    
    % Ordnernamen zerlegen mit Regex: 0.1_0.1_Pos_1_Q_1000_Glas_600
    paramTokens = regexp(folderName, '(?<gas>[\d\.]+)_(?<liq>[\d\.]+)_Pos_(?<pos>\d+)_(?<form>[A-Za-z]+)_(?<kanal>\d+)_(?<mat>[A-Za-z]+)_(?<nadel>\d+)', 'names');  
    
    % Fallback Variablen, falls der Ordnername nicht dem Schema entspricht
    vGasStr = "NaN"; vLiqStr = "NaN"; posNum = NaN; 
    formStr = "NaN"; kanalStr = "NaN"; matStr = "NaN"; nadelStr = "NaN";
    isDruckMessung = contains(folderName, 'Druck', 'IgnoreCase', true);

    if ~isempty(paramTokens)
        vGasStr   = string(paramTokens.gas);
        vLiqStr   = string(paramTokens.liq);
        posNum    = str2double(paramTokens.pos);
        formStr   = string(paramTokens.form);
        kanalStr  = string(paramTokens.kanal);
        matStr    = string(paramTokens.mat);
        nadelStr  = string(paramTokens.nadel);
    end
    
    % --- LABORBUCH ABFRAGEN ---
    labMatchIdx = find(strcmp(string(labTable.Dateiname), folderName));
    
    % 1. Fehler: Ordner existiert gar nicht im Laborbuch
    if isempty(labMatchIdx)
        warning('ÜBERSPRUNGEN: Ordner "%s" wurde im Laborbuch (Spalte "Dateiname") nicht gefunden!', folderName);
        continue; % Bricht die Auswertung dieses Videos ab und geht zum nächsten
    end
    
    p_Pa       = labTable.Umgebungsdruck(labMatchIdx(1));
    temp_C     = labTable.Umgebungstemperatur(labMatchIdx(1));
    co2_anteil = labTable.("CO2-Anteil")(labMatchIdx(1));
    reaktor_L     = labTable.Kanallaenge(labMatchIdx(1));
    kanalStart_mm = labTable.Offset(labMatchIdx(1));
    
    % 2. Fehler: Einzelne Zellen im Laborbuch sind leer (NaN)
    if ismissing(p_Pa) || isnan(p_Pa)
        warning('ÜBERSPRUNGEN: Im Laborbuch fehlt der "Umgebungsdruck" für den Ordner "%s"!', folderName);
        continue;
    end
    
    if ismissing(temp_C) || isnan(temp_C)
        warning('ÜBERSPRUNGEN: Im Laborbuch fehlt die "Umgebungstemperatur" für den Ordner "%s"!', folderName);
        continue;
    end
    
    if ismissing(co2_anteil) || isnan(co2_anteil)
        warning('ÜBERSPRUNGEN: Im Laborbuch fehlt der "CO2-Anteil" für den Ordner "%s"!', folderName);
        continue;
    end
       
    if ismissing(reaktor_L) || isnan(reaktor_L)
        warning('ÜBERSPRUNGEN: Im Laborbuch fehlt "Kanallaenge_cm" für Ordner "%s"!', folderName); 
        continue; 
    end
    
    if ismissing(kanalStart_mm) || isnan(kanalStart_mm)
        warning('ÜBERSPRUNGEN: Im Laborbuch fehlt "Offset_mm" für Ordner "%s"!', folderName); 
        continue; 
    end

    % Parameter für diesen parfor-Thread lokal speichern
    localParams = params;
    localParams.videoFile = videoFile;
    localParams.kanalStart_mm = kanalStart_mm;
    
    try        
        if isKey(calibMap, groupName)
            px2mm = calibMap(groupName);
        else
            error('Schlüssel "%s" existiert nicht in der calibMap!', groupName);
        end

        sensToTest = [0.85, 0.75, 0.9, 0.95, 0.8, 0.7, 0.65]; 
        
        bestStatsTable = table(); 
        bestSens = NaN;

        
        
        for sensIdx = 1:length(sensToTest)
            % Aktuelle Sensitivität für diesen Durchlauf in die Parameter schreiben
            localParams.sens = sensToTest(sensIdx);
            
            v = VideoReader(localParams.videoFile);
            
            % Bildbereich definieren
            imgH = v.Height; imgW = v.Width;
            roi = struct('y0', 1, 'y1', imgH, 'x0', 1, 'x1', imgW);

            v.CurrentTime = 0;
            bubbleTracker = []; 
            nextBubbleID = 1;
            prevBubbleCentroids = []; 
            channelHeightEstimate = NaN; 
            frameIdx = 0;
        
            % Videobilder einzeln durchgehen
            while hasFrame(v)
                frameIdx = frameIdx + 1;
                I_full = readFrame(v);
                if ndims(I_full) == 3, I_full = rgb2gray(I_full); end
                I_roi = I_full(roi.y0:roi.y1, roi.x0:roi.x1);
                
                % Blasen detektieren
                [currentBubbleCentroids, channelHeightEstimate, ~, ~] = ...
                    detect_Bubbles(I_roi, channelHeightEstimate, localParams);
                
                % Blasen tracken
                [bubbleTracker, prevBubbleCentroids, nextBubbleID] = track_Bubbles(...
                    currentBubbleCentroids, prevBubbleCentroids, bubbleTracker, nextBubbleID, frameIdx, localParams.maxJumpDist_px);
            end
            
            if ~isempty(bubbleTracker)
                % Blase 1 filtern
                if posNum == 1
                    bubbleTracker = bubbleTracker([bubbleTracker.ID] ~= 1);
                end
            end

            imgW = roi.x1 - roi.x0 + 1; 
            mean_UC_mm = NaN; 
            
            % Physik berechnen (Geschwindigkeiten, Längen)
            [~, statsTable] = evaluate_Physics(bubbleTracker, px2mm, localParams.fps, ...
                localParams.minFramesTracked, imgW, localParams.kanalStart_mm, localParams.binSize_mm, mean_UC_mm);
            
            % Die Funktion prüft Länge, Geschwindigkeit und Blasenanzahl
            isGood = evaluate_DetectionQuality(statsTable);
            
            if isGood
                % Perfekt! Ergebnis speichern und die Sensitivitäts-Schleife abbrechen
                bestStatsTable = statsTable;
                bestSens = localParams.sens;
                break; 
            else
                % Fallback: Wenn es das allererste Ergebnis ist (Standard-Sensitivität), 
                % merken wir es uns, falls ALLE anderen Sensitivitäten auch scheitern.
                if sensIdx == 1
                    bestStatsTable = statsTable;
                    bestSens = localParams.sens;
                end
            end
        end

        statsTable = bestStatsTable;
        bestSens = bestSens; % (Stellt sicher, dass die Variable im Workspace der Worker existiert)
        
        % --- METADATEN ZUR TABELLE HINZUFÜGEN ---
        numRowsStats = height(statsTable);
        if numRowsStats > 0
            if isDruckMessung
                messartStr = "Druckkalibrierung";
            else
                messartStr = "Massentransfer";
            end
            % Eine Tabelle mit den neu ausgelesenen Konstanten erstellen
            MetaDataStats = table(...
                repmat(vGasStr, numRowsStats, 1), ...
                repmat(vLiqStr, numRowsStats, 1), ...
                repmat(posNum, numRowsStats, 1), ...
                repmat(matStr, numRowsStats, 1), ...
                repmat(formStr, numRowsStats, 1), ...
                repmat(str2double(kanalStr), numRowsStats, 1), ...
                repmat(str2double(nadelStr), numRowsStats, 1), ...
                repmat(reaktor_L, numRowsStats, 1), ...
                repmat(p_Pa, numRowsStats, 1), ...
                repmat(temp_C, numRowsStats, 1), ...
                repmat(co2_anteil, numRowsStats, 1), ...
                repmat(messartStr, numRowsStats, 1), ...
                repmat(bestSens, numRowsStats, 1), ...
                'VariableNames', {'GasVelocity', 'LiquidVelocity', 'CameraPosition', ...
                                  'Material', 'Geometrie', 'Kanal_um', 'Nadel_um', ...
                                  'Reaktor_cm', 'Druck_Pa_Auslass', 'Temperatur_C', 'CO2_Anteil', 'Messart', 'UsedSensitivity'});
            
            % Beide Tabellen (Metadaten + Physik-Daten) horizontal zusammenfügen
            statsTable = [MetaDataStats, statsTable];
            statsTable.Properties.RowNames = {};
        end
    
    % In Cell-Array ablegen für Zusammenfassung nach der parfor-Schleife
    statsCell{vIdx} = statsTable;
        
    catch ME
        warning('Fehler bei Video %d (%s): %s', vIdx, folderName, ME.message);
    end
    send(D, 1);
end

try close(wb); catch; end 
fprintf('\nAuswertung aller Videos abgeschlossen!\n');

% -------------------------------------------------------------------------
% 5. ERGEBNISSE ZUSAMMENFASSEN & AUTOMATISCH BENENNEN
% -------------------------------------------------------------------------
validStatsIdx = cellfun(@(x) ~isempty(x) && istable(x) && height(x) > 0, statsCell);
statsCell = statsCell(validStatsIdx);

if ~isempty(statsCell)
    % Alle einzelnen Video-Tabellen untereinanderhängen
    MasterTableStats = vertcat(statsCell{:});
    
    % Finde alle einzigartigen Messarten in der Gesamttabelle (z.B. "Massentransfer" und "Druckkalibrierung")
    messarten = unique(MasterTableStats.Messart);
    
    % Schleife über die gefundenen Messarten, um sie getrennt zu speichern
    for m = 1:length(messarten)
        aktuelleMessart = string(messarten(m));
        
        % Filtere die große Tabelle nach der aktuellen Messart
        teilTabelle = MasterTableStats(string(MasterTableStats.Messart) == aktuelleMessart, :);
        
        % Dynamischen Dateinamen anhand der ersten Zeile dieser TEIL-Tabelle generieren
        outMat   = teilTabelle.Material(1);
        outForm  = teilTabelle.Geometrie(1);
        outKanal = num2str(teilTabelle.Kanal_um(1));
        outLen   = num2str(teilTabelle.Reaktor_cm(1));
        outNadel = num2str(teilTabelle.Nadel_um(1));
        outCO2   = num2str(teilTabelle.CO2_Anteil(1) * 100); 
        
        % Ordner und Prefix basierend auf der aktuellen Messart festlegen
        if aktuelleMessart == "Druckkalibrierung"
            outFolder = fullfile(pwd, 'Ausgabe_Druckkalibrierung');
            prefix = 'Auswertung_Druck';
        else
            outFolder = fullfile(pwd, 'Ausgabe_Massentransfer');
            prefix = 'Auswertung_Masse';
        end
        
        % Ordner erstellen, falls er noch nicht existiert
        if ~exist(outFolder, 'dir')
            mkdir(outFolder);
        end
        
        % Dateiname bauen
        fileName = sprintf('%s_%s_%s_%sum_%scm_%smolCO2_%sum.csv', ...
                            prefix, outMat, outForm, outKanal, outLen, outCO2, outNadel);
        
        savePath = fullfile(outFolder, fileName);
        
        % Speichern
        writetable(teilTabelle, savePath, 'Delimiter', ';');
        fprintf('ERFOLG: %d Zeilen gespeichert in Ordner:\n%s\nDateiname: %s\n', height(teilTabelle), outFolder, fileName);
    end
    
    % Plots generieren (falls gewollt)
    % plotsDir = fullfile(baseDir, 'Geschwindigkeits_Plots');
    % generate_Batch_Plots(table(), MasterTableStats, plotsDir);
    
else
    fprintf('Keine validen Daten zur Speicherung gefunden.\n');
end

% =========================================================================
% LOKALE FUNKTIONEN
% =========================================================================
function updateWaitbar(wb, numTotal)
    % persistent speichert den Wert zwischen den Aufrufen der Funktion
    persistent count
    if isempty(count)
        count = 1;
    else
        count = count + 1;
    end
    
    % Prozentzahl berechnen
    pct = count / numTotal;
    
    % Ladebalken aktualisieren (falls das Fenster nicht vom Nutzer geschlossen wurde)
    try
        waitbar(pct, wb, sprintf('Auswertung läuft... %.1f%% (%d von %d)', pct*100, count, numTotal));
    catch
        % Fenster wurde manuell geschlossen, Fehler ignorieren
    end
    
    % Zähler für den nächsten Batch-Run zurücksetzen, wenn wir fertig sind
    if count == numTotal
        clear count; 
    end
end