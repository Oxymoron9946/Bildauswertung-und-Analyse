function start_AnalysisFromGUI(mode, config, targetPath)
% START_ANALYSISFROMGUI Wrapper-Funktion für die App.
% Iteriert über alle in der GUI ausgewählten Sensitivitäten.

    projectRoot = fileparts(fileparts(fileparts(mfilename('fullpath'))));

    % Falls sensArray nicht existiert (Abwärtskompatibilität), nutze sens
    if ~isfield(config.detection, 'sensArray')
        config.detection.sensArray = config.detection.sens;
    end

    if strcmp(mode, 'single')
        fprintf('GUI startet Einzelvideo-Auswertung...\n');
        
        calibFile = config.paths.calibFile;
        videoFile = targetPath;
        
        % Basis-Parameter setzen
        params.videoFile             = videoFile;
        params.calibFile             = calibFile;
        params.fps                   = config.video.fps;
        params.showCalibrationImage  = config.ui.showCalibrationImage;
        params.showVisuals           = config.ui.showVisuals;
        params.visualizeEveryNFrames = config.ui.visualizeEveryNFrames;
        params.dimOffsetY            = config.ui.dimOffsetY;
        params.minPixel              = config.detection.minPixel;
        params.minArea               = config.detection.minArea;
        params.borderMargin          = config.detection.borderMargin;
        params.maxJumpDist_px        = config.tracking.maxJumpDist_px;
        params.minFramesTracked      = config.tracking.minFramesTracked;
        params.kanalStart_mm         = config.physics.kanalStart_mm;
        params.binSize_mm            = config.physics.binSize_mm;
        params.closeWidth            = config.detection.closeWidth;
        params.closeHeight           = config.detection.closeHeight;
        params.showBinarySteps       = config.ui.showBinarySteps;
        params.showVelocityTracking  = config.ui.showVelocityTracking;
        params.exportImages          = config.ui.exportImages;
        params.exportFrame           = config.ui.exportFrame;

        % --- Offset aus dem Laborbuch auslesen (statt blindem Config-Fallback) ---
        [videoFolder, ~, ~] = fileparts(videoFile);
        folders = strsplit(videoFolder, filesep);
        if contains(folders{end}, 'fps', 'IgnoreCase', true)
            folderName = folders{end-1};
        else
            folderName = folders{end};
        end
        labTable = load_Laborbuch(config.paths.laborbuch);
        labMatchIdx = find(strcmp(string(labTable.Dateiname), folderName));
        if ~isempty(labMatchIdx) && ~ismissing(labTable.Offset(labMatchIdx(1))) && ~isnan(labTable.Offset(labMatchIdx(1)))
            params.kanalStart_mm = labTable.Offset(labMatchIdx(1));
            fprintf('Offset aus Laborbuch für "%s": %.1f mm.\n', folderName, params.kanalStart_mm);
        else
            fprintf('Kein Laborbuch-Eintrag für "%s" gefunden – nutze Config-Fallback (Offset = %.1f mm).\n', folderName, params.kanalStart_mm);
        end

        allStats = cell(length(config.detection.sensArray), 1);
        lastResultsTable = [];  % Speichere die letzte resultsTable für die Visualisierung

        % Schleife über alle ausgewählten Sensitivitäten
        for sIdx = 1:length(config.detection.sensArray)
            currentSens = config.detection.sensArray(sIdx);
            fprintf('--- Durchlauf %d/%d (Sensitivität: %.2f) ---\n', sIdx, length(config.detection.sensArray), currentSens);
            
            % Setze die aktuelle Sensitivität für diesen Durchlauf
            params.sens = currentSens;
            
            % Pipeline aufrufen
            [resultsTable, statsTable, ~, ~] = runAnalysisPipeline(videoFile, calibFile, config, params);
            
            % resultsTable für die spätere Visualisierung merken
            if ~isempty(resultsTable)
                lastResultsTable = resultsTable;
            end
            
            % Sensitivität als Spalte hinzufügen, falls Daten vorhanden
            if ~isempty(statsTable)
                numRows = height(statsTable);
                sensCol = table(repmat(currentSens, numRows, 1), 'VariableNames', {'UsedSensitivity'});
                statsTable = [sensCol, statsTable];
                allStats{sIdx} = statsTable;
            end
        end
            
        % Ergebnisse zusammenführen und speichern
        validStatsIdx = cellfun(@(x) ~isempty(x), allStats);
        if any(validStatsIdx)
            MasterTable = vertcat(allStats{validStatsIdx});
            
            % Zielordner und Dateiname basierend auf dem Ordnernamen wählen
            if contains(folderName, 'Druck', 'IgnoreCase', true)
                outSubfolder = 'Output_PressureCalibration';
                filePrefix = 'Analysis_Pressure_';
            else
                outSubfolder = 'Output_MassTransfer';
                filePrefix = 'Analysis_Mass_';
            end
            outFolder = fullfile(projectRoot, 'output', outSubfolder);
            if ~exist(outFolder, 'dir')
                mkdir(outFolder);
            end
            outputFile = fullfile(outFolder, sprintf('%s%s.csv', filePrefix, folderName));
            
            writetable(MasterTable, outputFile);
            fprintf('Gesamtergebnis gespeichert unter: %s\n', outputFile);
        else
            fprintf('Keine validen Daten zur Speicherung gefunden.\n');
        end
        
        % Feedback-Plot direkt in die App zeichnen
        if isfield(config.ui, 'appAxes') && ~isempty(config.ui.appAxes) && isvalid(config.ui.appAxes)
            visualize_Results(lastResultsTable, [], config.ui.appAxes);
        end
        
    elseif strcmp(mode, 'batch')
        fprintf('GUI startet Batch-Auswertung...\n');
        
        % baseDir ist der in der GUI ausgewählte Ordner
        baseDir = targetPath;
        
        % Batch-Pipeline aufrufen
        % Hinweis: Für eine 100% responsive GUI sollte dies später über parfeval
        % ausgelagert werden. Für den Moment rufen wir es direkt auf.
        runBatchPipeline(config, baseDir);
        
        fprintf('Batch-Auswertung erfolgreich abgeschlossen.\n');
    else
        error('Unbekannter Modus: %s', mode);
    end
end