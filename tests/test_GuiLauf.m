classdef test_GuiLauf < matlab.unittest.TestCase
% TEST_GUILAUF Ein vollständiger GUI-Lauf liefert dasselbe wie Skript und Wiederholung.
%
% Startet die App, wertet ein Video über den Start-Knopf aus und vergleicht
% die CSV bytegenau mit (1) der Skript-Auswertung und (2) der Wiederholung
% aus der gespeicherten lauf_config_*.json. Braucht die Messvideos (ca. 3 min).

    properties (Constant)
        VIDEO = fullfile('PVC_1500_1150', 'Druck', 'Pos_1_Kal_3', '0.198_0.111_Pos_1_R_1500_PVC_1150_Druck', ...
            '200fps_001', 'XSM-3520 Camera 0330_.avi');
    end

    methods (TestClassSetup)
        function projektPfad(testCase)
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture( ...
                fileparts(fileparts(mfilename('fullpath')))));
        end
    end

    methods (Test)
        function guiGleichSkriptGleichWiederholung(testCase)
            cfg = config();
            video = fullfile(cfg.pfade.messdaten, test_GuiLauf.VIDEO);
            testCase.assumeTrue(isfile(video), 'Messvideo fehlt.');
            tmp = testCase.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture).Folder;

            % 1. GUI
            cfg.pfade.ausgabe = fullfile(tmp, 'gui');
            fig = videoauswertung.gui.VideoAnalysisApp(cfg);
            testCase.addTeardown(@() delete(fig(isvalid(fig))));
            pfad = findall(fig, 'Type', 'uieditfield');
            pfad.Value = video;
            start = findall(fig, 'Type', 'uibutton', 'Text', 'Start');
            start.ButtonPushedFcn(start, []);
            status = findall(fig, 'Type', 'uilabel', 'Text', 'Fertig.');
            testCase.assertNotEmpty(status, 'GUI-Lauf nicht mit "Fertig." beendet.');
            guiCsv = dir(fullfile(cfg.pfade.ausgabe, '**', '*.csv'));
            testCase.assertNumElements(guiCsv, 1);

            % 2. Skript
            skript = config();
            skript.pfade.ausgabe = fullfile(tmp, 'skript');
            skriptCsv = videoauswertung.kern.auswerten_Einzel(skript, video);
            testCase.verifyEqual(fileread(skriptCsv), fileread(fullfile(guiCsv.folder, guiCsv.name)));

            % 3. Wiederholung aus der Laufdatei der GUI
            json = dir(fullfile(cfg.pfade.ausgabe, 'lauf_config_*.json'));
            testCase.assertNumElements(json, 1);
            neu = videoauswertung.kern.wiederhole_Lauf(fullfile(json.folder, json.name), fullfile(tmp, 'wiederholt'));
            testCase.verifyEqual(fileread(neu{1}), fileread(skriptCsv));
        end
    end
end
