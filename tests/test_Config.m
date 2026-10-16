classdef test_Config < matlab.unittest.TestCase
% TEST_CONFIG Prüft config.m und pruefe_Config.

    methods (TestClassSetup)
        function projektPfad(testCase)
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture( ...
                fileparts(fileparts(mfilename('fullpath')))));
        end
    end

    methods (Test)
        function standardIstGueltig(testCase)
            cfg = config();
            testCase.verifyClass(cfg, 'struct');
            testCase.verifyWarningFree(@() videoauswertung.kern.pruefe_Config(cfg));
        end

        function pfadeUnabhaengigVomArbeitsordner(testCase)
            testCase.applyFixture(matlab.unittest.fixtures.CurrentFolderFixture(tempdir));
            cfg = config();
            testCase.verifyTrue(isfile(cfg.pfade.laborbuch));
            testCase.verifyEqual(cfg.pfade.projekt, fileparts(fileparts(mfilename('fullpath'))));
        end

        function negativeFpsWirdAbgelehnt(testCase)
            cfg = config();
            cfg.video.fps = -10;
            testCase.verifyError(@() videoauswertung.kern.pruefe_Config(cfg), 'videoauswertung:config');
        end

        function sensAusserhalbWirdAbgelehnt(testCase)
            cfg = config();
            cfg.detektion.sens = 1.5;
            testCase.verifyError(@() videoauswertung.kern.pruefe_Config(cfg), 'videoauswertung:config');
        end

        function fehlendesLaborbuchWirdAbgelehnt(testCase)
            cfg = config();
            cfg.pfade.laborbuch = fullfile(tempdir, 'gibt_es_nicht.csv');
            testCase.verifyError(@() videoauswertung.kern.pruefe_Config(cfg), 'videoauswertung:config');
        end
    end
end
