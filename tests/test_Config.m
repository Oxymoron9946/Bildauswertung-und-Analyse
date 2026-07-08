classdef test_Config < matlab.unittest.TestCase
    % TEST_CONFIG Unit Tests für die Konfigurationsfunktionen.
    
    properties
        ProjectRoot
    end
    
    methods (TestMethodSetup)
        function setupPaths(testCase)
            % Finde das Projektverzeichnis basierend auf dem Pfad dieser Testdatei
            testDir = fileparts(mfilename('fullpath'));
            testCase.ProjectRoot = fileparts(testDir);
            
            % Füge src/config zum Pfad hinzu, damit defaultConfig gefunden wird
            addpath(fullfile(testCase.ProjectRoot, 'src', 'config'));
        end
    end
    
    methods (Test)
        function testDefaultConfigReturnsStruct(testCase)
            % Prüft, ob defaultConfig einen gültigen Struct zurückgibt
            config = defaultConfig(testCase.ProjectRoot);
            testCase.verifyClass(config, 'struct');
            testCase.verifyTrue(isfield(config, 'video'));
            testCase.verifyTrue(isfield(config, 'detection'));
        end
        
        function testValidateConfigPassesValidConfig(testCase)
            % Prüft, ob die Standardkonfiguration die Validierung besteht
            config = defaultConfig(testCase.ProjectRoot);
            % Sollte keinen Fehler werfen
            validConfig = validateConfig(config);
            testCase.verifyEqual(validConfig.video.fps, 200);
        end
        
        function testValidateConfigCatchesNegativeFPS(testCase)
            % Prüft, ob negative FPS korrekt abgefangen werden
            config = defaultConfig(testCase.ProjectRoot);
            config.video.fps = -10;
            
            % Erwarte, dass validateConfig einen Fehler wirft
            testCase.verifyError(@() validateConfig(config), '');
        end
        
        function testValidateConfigCatchesInvalidSens(testCase)
            % Prüft, ob ungültige Sensitivität abgefangen wird
            config = defaultConfig(testCase.ProjectRoot);
            config.detection.sens = 1.5; % Nur 0 bis 1 erlaubt
            
            testCase.verifyError(@() validateConfig(config), '');
        end
    end
end