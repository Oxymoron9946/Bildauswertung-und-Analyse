classdef test_GuiStart < matlab.unittest.TestCase
% TEST_GUISTART Rauchtest: die App startet ohne Fehler und lässt sich schließen.

    methods (TestClassSetup)
        function projektPfad(testCase)
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture( ...
                fileparts(fileparts(mfilename('fullpath')))));
        end
    end

    methods (Test)
        function startetUndSchliesst(testCase)
            fig = videoauswertung.gui.VideoAnalysisApp();
            testCase.addTeardown(@() delete(fig(isvalid(fig))));
            drawnow;
            testCase.verifyTrue(isvalid(fig));
            testCase.verifyNotEmpty(findall(fig, 'Type', 'uibutton', 'Text', 'Start'));
            delete(fig);
            testCase.verifyFalse(isvalid(fig));
        end

        function startwerteAusConfig(testCase)
            cfg = config();
            cfg.detektion.sens = 0.77;
            fig = videoauswertung.gui.VideoAnalysisApp(cfg);
            testCase.addTeardown(@() delete(fig(isvalid(fig))));
            felder = findall(fig, 'Type', 'uinumericeditfield');
            testCase.verifyTrue(any([felder.Value] == 0.77));
        end
    end
end
