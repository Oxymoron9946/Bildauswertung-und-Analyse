function config = defaultConfig(projectRoot)
% DEFAULTCONFIG Erzeugt den zentralen Parameter-Struct für die Videoauswertung.
% 
% Eingabe:
%   projectRoot - Absoluter Pfad zum Hauptverzeichnis des Projekts
%
% Ausgabe:
%   config - Struct mit allen Standardparametern

    config = struct();
    
    % --- Pfade & I/O ---
    % Standardmäßig auf die Testdaten aus run_Single ausgerichtet
    config.paths.videoFile = fullfile(projectRoot, 'PTFE_1000_600', 'Auswertung_20_CO2', 'Pos_1_Kal_1', '0.134_0.167_Pos_1_R_1000_PTFE_600', '200fps_001', 'XSM-3520 Camera 0330_.avi');
    config.paths.calibFile = fullfile(projectRoot, 'PTFE_1000_600', 'Auswertung_20_CO2', 'Pos_1_Kal_1', 'Kalibrierung_1_Pos_1_08.04.2026_001', 'XSM-3520 Camera 0330_.avi');
    config.paths.laborbuch = fullfile(projectRoot, 'data', 'Laborbuch.csv');
    config.paths.exportDir = fullfile(projectRoot, 'output', 'figures'); 
    
    % --- Video & Globale Metadaten ---
    config.video.fps = 200;
    
    % --- Detektion (detect_Bubbles) ---
    config.detection.minPixel     = 50;
    config.detection.minArea      = 100;
    config.detection.borderMargin = 2;
    config.detection.closeWidth   = 5;
    config.detection.closeHeight  = 5;
    config.detection.sens         = 0.95;
    
    % --- Tracking (track_Bubbles) ---
    config.tracking.maxJumpDist_px   = 50;
    config.tracking.minFramesTracked = 10;
    
    % --- Physik (evaluate_Physics) ---
    config.physics.binSize_mm    = 4;
    config.physics.kanalStart_mm = 0;
    
    % --- UI & Visualisierung ---
    config.ui.showVisuals           = true; 
    config.ui.showCalibrationImage  = true;
    config.ui.visualizeEveryNFrames = 10;
    config.ui.dimOffsetY            = 45;
    config.ui.showBinarySteps       = false;
    config.ui.showVelocityTracking  = true;
    config.ui.exportImages          = true;
    config.ui.exportFrame           = 15;
end