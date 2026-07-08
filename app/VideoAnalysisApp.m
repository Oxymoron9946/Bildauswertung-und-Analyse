function VideoAnalysisApp()
% VIDEOANALYSISAPP Programmatische Dashboard-GUI für die Videoauswertung.
    % 1. Hauptfenster erstellen (Breiter und höher für Dashboard-Look)
    fig = uifigure('Name', 'Video Analysis Dashboard', 'Position', [100 50 1000 800]);
    
    % =====================================================================
    % OBERER BEREICH: BEDIENELEMENTE (Höhe: 250px)
    % =====================================================================
    controlPanel = uipanel(fig, 'Position', [10 540 980 250], 'Title', 'Control Panel', 'FontWeight', 'bold');
    
    % --- Spalte 1: Modus & Dateiauswahl ---
    bg = uibuttongroup(controlPanel, 'Position', [10 160 300 60], 'Title', 'Mode Selection', 'SelectionChangedFcn', @modeChanged);
    uiradiobutton(bg, 'Position', [10 15 100 22], 'Text', 'Single Video', 'Tag', 'single');
    uiradiobutton(bg, 'Position', [150 15 150 22], 'Text', 'Batch Processing', 'Tag', 'batch');
    
    uilabel(controlPanel, 'Position', [10 130 100 22], 'Text', 'Target Path:');
    pathEditField = uieditfield(controlPanel, 'text', 'Position', [10 105 200 22]);
    uibutton(controlPanel, 'Position', [220 105 90 22], 'Text', 'Browse...', 'ButtonPushedFcn', @browsePushed);
    
    % --- Spalte 2: Parameter ---
    uilabel(controlPanel, 'Position', [340 200 100 22], 'Text', 'Sens. Start:');
    sensStartEdit = uieditfield(controlPanel, 'numeric', 'Position', [420 200 80 22], 'Value', 0.85);
    
    uilabel(controlPanel, 'Position', [340 160 100 22], 'Text', 'Sens. End:');
    sensEndEdit = uieditfield(controlPanel, 'numeric', 'Position', [420 160 80 22], 'Value', 0.95);
    sensEndEdit.Enable = 'off'; % Standardmäßig Single-Modus
    
    uilabel(controlPanel, 'Position', [340 120 100 22], 'Text', 'Min Pixel:');
    minPixelEdit = uieditfield(controlPanel, 'numeric', 'Position', [420 120 80 22], 'Value', 50);
    
    uilabel(controlPanel, 'Position', [340 80 100 22], 'Text', 'FPS (Fallback):');
    fpsEdit = uieditfield(controlPanel, 'numeric', 'Position', [420 80 80 22], 'Value', 200);
    
    % --- Spalte 3: UI Optionen ---
    liveViewCheck = uicheckbox(controlPanel, 'Position', [540 200 200 22], 'Text', 'Show Live Visualization', 'Value', 1);
    calibCheck = uicheckbox(controlPanel, 'Position', [540 160 200 22], 'Text', 'Show Calibration Image', 'Value', 0);
    exportCheck = uicheckbox(controlPanel, 'Position', [540 120 250 22], 'Text', 'Export Scientific Figures (Frame 15)', 'Value', 0);
    
    % --- Spalte 4: Ausführung ---
    startButton = uibutton(controlPanel, 'Position', [780 140 180 80], 'Text', 'Start Analysis', ...
        'FontSize', 16, 'FontWeight', 'bold', 'BackgroundColor', [0.2 0.6 0.2], 'FontColor', 'w', ...
        'ButtonPushedFcn', @startPushed);
        
    statusLabel = uilabel(controlPanel, 'Position', [780 100 180 22], 'Text', 'Ready.', 'HorizontalAlignment', 'center');
    % =====================================================================
    % UNTERER BEREICH: VISUALISIERUNG (Tabs)
    % =====================================================================
    tabGroup = uitabgroup(fig, 'Position', [10 10 980 520]);
    
    % Tab 1: Live Tracking
    tabLive = uitab(tabGroup, 'Title', 'Live Tracking');
    % Hier zeichnet die Pipeline später hinein!
    appAxes = uiaxes(tabLive, 'Position', [10 10 960 470]);
    title(appAxes, 'Waiting for video...');
    
    % Tab 2: Results Viewer (Vorbereitung für Phase 12)
    tabResults = uitab(tabGroup, 'Title', 'Results Viewer');
    uilabel(tabResults, 'Position', [400 250 200 22], 'Text', 'Dashboard coming soon...', 'FontSize', 14);
    % =====================================================================
    % CALLBACK FUNKTIONEN
    % =====================================================================
    function modeChanged(~, event)
        if strcmp(event.NewValue.Tag, 'batch')
            liveViewCheck.Enable = 'off'; liveViewCheck.Value = 0;
            calibCheck.Enable = 'off'; calibCheck.Value = 0;
            exportCheck.Enable = 'off'; exportCheck.Value = 0;
            sensEndEdit.Enable = 'on';
        else
            liveViewCheck.Enable = 'on'; liveViewCheck.Value = 1;
            calibCheck.Enable = 'on'; 
            exportCheck.Enable = 'on';
            sensEndEdit.Enable = 'off';
        end
        pathEditField.Value = '';
    end
    function browsePushed(~, ~)
        if strcmp(bg.SelectedObject.Tag, 'single')
            [file, path] = uigetfile('*.avi', 'Select a video file');
            if ~isequal(file, 0), pathEditField.Value = fullfile(path, file); end
        else
            path = uigetdir('', 'Select the main directory');
            if ~isequal(path, 0), pathEditField.Value = path; end
        end
    end
    function startPushed(~, ~)
        targetPath = pathEditField.Value;
        if isempty(targetPath)
            uialert(fig, 'Please select a file or directory first!', 'Error'); return;
        end
        
        projectRoot = fileparts(fileparts(mfilename('fullpath'))); 
        addpath(fullfile(projectRoot, 'src', 'config'));
        addpath(fullfile(projectRoot, 'src', 'core'));
        addpath(fullfile(projectRoot, 'src', 'io'));     
        addpath(fullfile(projectRoot, 'src', 'utils'));  
        config = defaultConfig(projectRoot);
        
        mode = bg.SelectedObject.Tag;
        
        fpsToken = regexp(targetPath, '(\d+)fps', 'tokens');
        if ~isempty(fpsToken)
            config.video.fps = str2double(fpsToken{end}{1});
            fpsEdit.Value = config.video.fps; 
        else
            config.video.fps = fpsEdit.Value; 
        end
        
        if strcmp(mode, 'single')
            config.detection.sensArray = sensStartEdit.Value;
        else
            config.detection.sensArray = sensStartEdit.Value : 0.05 : sensEndEdit.Value;
            if isempty(config.detection.sensArray), config.detection.sensArray = sensStartEdit.Value; end
        end
        
        config.detection.minPixel  = minPixelEdit.Value;
        config.ui.showVisuals          = liveViewCheck.Value;
        config.ui.showCalibrationImage = calibCheck.Value;
        config.ui.exportImages         = exportCheck.Value; 
        
        % NEU: Übergebe die App-Achsen an die Config, damit die Pipeline sie nutzen kann
        config.ui.appAxes = appAxes;
        
        try
            startButton.Enable = 'off';
            statusLabel.Text = 'Analysis running...';
            % Wechsle automatisch zum Live-Tracking Tab
            tabGroup.SelectedTab = tabLive;
            drawnow; 
            
            start_AnalysisFromGUI(mode, config, targetPath);
            
            statusLabel.Text = 'Completed successfully!';
        catch ME
            statusLabel.Text = 'An error occurred!';
            uialert(fig, ME.message, 'Execution Error');
        end
        startButton.Enable = 'on';
    end
end