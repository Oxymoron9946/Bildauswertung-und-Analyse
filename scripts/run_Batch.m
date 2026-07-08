%% Parallele Batch-Auswertung (Inkl. Metadaten- & Setup-Integration)
%
% ZWECK (Batch vs. Einzel):
%   Dieses Skript wertet viele Messvideos parallel aus, verknüpft sie mit dem
%   Laborbuch und schreibt zusammengeführte CSV-Ergebnisse.
%   run_Single.m dient der Entwicklung derselben Detektions-/Tracking-Logik und
%   bietet visuelles Feedback (Live-Ansicht, optionale Binärstufen) zur manuellen
%   Kontrolle einzelner Aufnahmen — die Methodik in der Arbeit bezieht sich auf
%   den Batch-Ablauf hier.
%
clc; close all; clear;

% Pfadkonfiguration: src/-Unterordner für die neue Projektstruktur einbinden
scriptDir = fileparts(mfilename('fullpath'));
projectRoot = fileparts(scriptDir);
addpath(fullfile(projectRoot, 'src', 'core'));
addpath(fullfile(projectRoot, 'src', 'io'));
addpath(fullfile(projectRoot, 'src', 'utils'));
addpath(fullfile(projectRoot, 'src', 'config'));

% =============================================================================
% BLOCK 1 — Metadaten-Pfad, globale Auswerteparameter, Laborbuch einlesen
% =============================================================================
% Alles bis einschließlich labTable gehört zur Konfigurationsschicht: keine
% Videos werden hier noch verarbeitet. Später matcht parfor je Messordner über
% labTable.Dateiname und liest Umgebungs-/Geometrie-Größen aus den gleichen Zeilen.

% -------------------------------------------------------------------------
% 0. PFADE ZU DEN METADATEN-DATEIEN (HIER ANPASSEN!)
% -------------------------------------------------------------------------
% CSV aus Excel exportiert; Trennzeichen Semikolon (siehe readtable unten).
% Datei muss im aktuellen MATLAB-Arbeitsverzeichnis liegen oder Pfad anpassen.
laborbuchPath = fullfile(projectRoot, 'data', 'Laborbuch.csv');

% -------------------------------------------------------------------------
% 1. PARAMETER & KONFIGURATION (Zentral geladen)
% -------------------------------------------------------------------------
config = defaultConfig(projectRoot);
config = validateConfig(config);

% --- TEMPORÄRER ADAPTER ---
% Mapping für die Kernfunktionen, die noch den flachen params-Struct erwarten.
params.minPixel         = config.detection.minPixel;
params.minArea          = config.detection.minArea;
params.borderMargin     = config.detection.borderMargin;
params.maxJumpDist_px   = config.tracking.maxJumpDist_px;
params.minFramesTracked = config.tracking.minFramesTracked;
params.binSize_mm       = config.physics.binSize_mm;
params.fps              = config.video.fps;
params.closeWidth       = config.detection.closeWidth;
params.closeHeight      = config.detection.closeHeight;
params.sens             = config.detection.sens;

% UI-Elemente für Batch explizit deaktivieren
params.showVisuals          = false;
params.showCalibrationImage = false;
params.exportImages         = false;

% -------------------------------------------------------------------------
% 2. TABELLEN EINLESEN (Laborbuch)
% -------------------------------------------------------------------------
% Enthält pro Messordner u. a.: Dateiname (Schlüssel zum Abgleich mit Ordnernamen),
% Umgebungsdruck, Umgebungstemperatur, CO2-Anteil, Kanallaenge, Offset (mm).
% Diese Spalten werden in der parfor-Schleife ausgewertet; fehlende Werte führen
% zum Überspringen des betreffenden Videos (siehe dortige Prüfungen).
labTable = load_Laborbuch(laborbuchPath);

% =============================================================================
% BLOCK 2 — Basisordner, Kalibrier-Map (Pos_X_Kal_Y → px2mm), Messvideo-Liste
% =============================================================================
% Interaktiver Projektstamm, rekursive Suche, automatischer Massstab pro
% Kalibriergruppe aus dem ersten Frame (setup_Calibration). Anschließend
% Filter: Unterordner „Kalibrierung_*“ entfallen in der Messliste (kein
% Laborbuch-Match für diese Pfade — Details bei parfor).

% -------------------------------------------------------------------------
% 3. BATCH-PARAMETER & ORDNERWAHL (Videos)
% -------------------------------------------------------------------------
% Dialog „Ordner wählen“; Abbruch ohne Fehler, wenn der Nutzer cancelt.
baseDir = uigetdir('', 'Bitte den Hauptordner (z.B. "Glaskanal") auswählen');
if baseDir == 0, return; end

% Rekursiv alle Kamera-AVIs unter baseDir (Mess- und Kalibrieraufnahmen).
% Fest codierter Dateiname — nicht konfigurierbar ohne Codeänderung.
allVideoFiles = dir(fullfile(baseDir, '**', 'XSM-3520 Camera 0330_*.avi'));
if isempty(allVideoFiles)
    error('Keine passenden .avi Dateien gefunden!');
end

% --- Kalibrier-Map: ein px2mm pro Schlüssel Pos_<n>_Kal_<m> ---
% Schlüssel wird aus dem Ordnerpfad per Regex extrahiert; fehlt das Muster,
% wird diese Kalibrier-AVI übersprungen. Bei mehreren AVIs derselben Gruppe
% überschreibt der letzte erfolgreiche Lauf den Map-Eintrag still.
calibMap    = containers.Map('KeyType', 'char', 'ValueType', 'double');
calibFileMap = containers.Map('KeyType', 'char', 'ValueType', 'char');
fprintf('\n--- Lese Kalibrierungen ein ---\n');
calibVideoFiles = dir(fullfile(baseDir, '**', 'Kalibrierung_*', '*.avi'));
for c = 1:length(calibVideoFiles)
    cFolder = calibVideoFiles(c).folder;
    cName = calibVideoFiles(c).name;
    tok = regexp(cFolder, '(Pos_\d+_Kal_\d+)', 'tokens');
    if ~isempty(tok)
        groupName = tok{1}{1};
        vcalib = VideoReader(fullfile(cFolder, cName));
        firstFrameCalib = readFrame(vcalib);
        if ndims(firstFrameCalib) == 3
            firstFrameCalib = rgb2gray(firstFrameCalib);
        end
        % Batch ohne Pop-up (false); Kontrollfenster siehe main_einzel / showCalibrationImage.
        [px2mm_calib, calibSuccess] = setup_Calibration(firstFrameCalib, false);
        if calibSuccess
            calibMap(groupName) = px2mm_calib;
            calibFileMap(groupName) = fullfile(cFolder, cName);
            fprintf('Gruppe %s: %.5f mm/px\n', groupName, px2mm_calib);
        end
        % calibSuccess == false: kein Eintrag — zugehörige Messvideos brechen in parfor ab,
        % sobald dieselbe Gruppe aus dem Messpfad angefordert wird.
    end
end
fprintf('--------------------------------\n\n');

% Nur Messvideos: Pfade mit Unterordnernamen Kalibrierung_* ausschließen.
videoFiles = [];
for i = 1:length(allVideoFiles)
    if ~contains(allVideoFiles(i).folder, 'Kalibrierung_')
        videoFiles = [videoFiles; allVideoFiles(i)]; %#ok<AGROW>
    end
end

% =============================================================================
% BLOCK 3 — Auswahl je Messvideo: Kalibriergruppe, Messordnername, Laborbuch
% =============================================================================
% Eingabe: videoFiles (nur Messpfade, s. Filter oben). Pro Worker-Eintrag:
%   (1) Regex Pos_<n>_Kal_<m> im vollen Pfad → groupName → px2mm aus calibMap
%       (fehlendes Muster: warning + continue; fehlender Map-Eintrag: error im try).
%   (2) folderName = Name des Messlaufs für labTable.Dateiname; Sonderfall Unterordner
%       mit „fps“ im Namen → übergeordneter Ordner.
%   (3) Optional: Ordnernamen-Regex für Gas/Liq/Pos/Geometrie/Kanal/Material/Nadel;
%       Schema mismatch → NaN-Platzhalter, kein Abbruch.
%   (4) Laborbuch-Zeile: strcmp(Dateiname, folderName); fehlt die Zeile oder Pflicht-
%       spalten sind leer/NaN → warning + continue (kein CSV-Eintrag für dieses Video).
%   (5) „Druck“ im Ordnernamen → Flag Druckkalibrierung (später Messart-Spalte/Export).
% -------------------------------------------------------------------------
% 4. PARALLELE HAUPTSCHLEIFE (parfor)
% -------------------------------------------------------------------------
numTotal = length(videoFiles);
fprintf('Starte parallele Batch-Auswertung für %d Messvideos...\n', numTotal);

% Pfade für parfor-Worker vorbereiten (Broadcast-Variablen)
pathCore   = fullfile(projectRoot, 'src', 'core');
pathIO     = fullfile(projectRoot, 'src', 'io');
pathUtils  = fullfile(projectRoot, 'src', 'utils');
pathConfig = fullfile(projectRoot, 'src', 'config');

% Grafischen Ladebalken erstellen
wb = waitbar(0, sprintf('Starte Auswertung von %d Videos...', numTotal), 'Name', 'Batch-Fortschritt');
D = parallel.pool.DataQueue;

% Diese Funktion wird jedes Mal aufgerufen, wenn ein Worker ein Video fertig hat
afterEach(D, @(~) updateWaitbar(wb, numTotal)); 

statsCell = cell(numTotal, 1);

parfor vIdx = 1:length(videoFiles)
    % Pfade in jedem Worker setzen (parfor erbt das nicht automatisch)
    addpath(pathCore);
    addpath(pathIO);
    addpath(pathUtils);
    addpath(pathConfig);
    
    videoFile = fullfile(videoFiles(vIdx).folder, videoFiles(vIdx).name);
    
    % --- Kalibriergruppe aus dem Pfad (muss mit calibMap-Schlüssel übereinstimmen) ---
    groupTok = regexp(videoFile, '(Pos_\d+_Kal_\d+)', 'tokens');
    if isempty(groupTok)
        warning('ÜBERSPRUNGEN: Video hat kein "Pos_X_Kal_Y" im Pfad: %s', videoFile);
        continue;
    end
    groupName = groupTok{1}{1};
    
    % --- Messordner = Schlüssel zum Laborbuch (Spalte Dateiname) ---
    % Liegt die AVI in …/200fps/, ist der Messlauf der Elternordner (Laborbuch zeigt auf den Lauf).
    folders = strsplit(videoFiles(vIdx).folder, filesep);
    if contains(folders{end}, 'fps', 'IgnoreCase', true)
        folderName = folders{end-1}; 
    else
        folderName = folders{end}; 
    end
    
    % Optional: Parameter aus Benennungsschema des Messordners (kein Abbruch bei Fehlparser)
    paramTokens = regexp(folderName, '(?<gas>[\d\.]+)_(?<liq>[\d\.]+)_Pos_(?<pos>\d+)_(?<form>[A-Za-z]+)_(?<kanal>\d+)_(?<mat>[A-Za-z]+)_(?<nadel>\d+)', 'names');  
    
    % Fallback, falls Ordnername nicht dem Regex-Schema entspricht
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
    
    % --- Dynamische Einlauflänge berechnen ---
    L_ein_mm = NaN;
    if ~isnan(str2double(vGasStr)) && ~isnan(str2double(vLiqStr)) && ~isnan(str2double(kanalStr))
        j_G = str2double(vGasStr);
        j_L = str2double(vLiqStr);
        d_h_mm = str2double(kanalStr) / 1000; % um in mm
        d_h_m = d_h_mm / 1000; % mm in m
        
        % Annahme Wasser (kontinuierliche Phase): rho = 1000 kg/m^3, mu = 0.001 Pa*s
        rho = 1000;
        mu = 0.001;
        v_mix = j_G + j_L;
        
        Re = (rho * v_mix * d_h_m) / mu;
        L_ein_mm = 0.05 * Re * d_h_mm;
    end
    
    % --- Laborbuch: exakter Match Ordnername ↔ Spalte Dateiname (eine Zeile pro Messlauf) ---
    labMatchIdx = find(strcmp(string(labTable.Dateiname), folderName));
    
    % 1. Kein Zeilen-Match → Video überspringen
    if isempty(labMatchIdx)
        warning('ÜBERSPRUNGEN: Ordner "%s" wurde im Laborbuch (Spalte "Dateiname") nicht gefunden!', folderName);
        continue; % Bricht die Auswertung dieses Videos ab und geht zum nächsten
    end
    
    p_Pa       = labTable.Umgebungsdruck(labMatchIdx(1));
    temp_C     = labTable.Umgebungstemperatur(labMatchIdx(1));
    co2_anteil = labTable.("CO2-Anteil")(labMatchIdx(1));
    reaktor_L     = labTable.Kanallaenge(labMatchIdx(1));
    kanalStart_mm = labTable.Offset(labMatchIdx(1));
    
    % 2. Pflichtfelder aus der Laborbuch-Zeile: leer oder NaN → Video überspringen
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
            calibFile = calibFileMap(groupName);
        else
            error('Schlüssel "%s" existiert nicht in der calibMap!', groupName);
        end

        % --- KERNLOGIK AUFRUFEN ---
        % Die gesamte Frame-Verarbeitung ist nun in runAnalysisPipeline gekapselt.
        % Dies macht die parfor-Schleife extrem stabil und übersichtlich.
        [resultsTable, statsTable, mean_UC_mm, L_ein_mm] = runAnalysisPipeline(...
            videoFile, calibFile, config, localParams);

        bestSens = localParams.sens;
        
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
                repmat(bestSens, numRowsStats, 1), ... % UsedSensitivity = gewähltes sens aus Block 5
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

% =============================================================================
% BLOCK 7 — Ergebniszusammenführung und CSV-Export
% =============================================================================
% Exportiere die Ergebnisse in den Output-Ordner des Projekts
outputBaseDir = fullfile(projectRoot, 'output');
export_BatchResults(statsCell, outputBaseDir);

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