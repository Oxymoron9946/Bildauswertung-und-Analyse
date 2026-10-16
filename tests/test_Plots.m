classdef test_Plots < matlab.unittest.TestCase
% TEST_PLOTS Jeder Plot entsteht ohne Fehler, in beiden Sprachen, im hellen Theme.

    properties (TestParameter)
        sprache = {'de', 'en'};
    end

    properties
        Stil
        Roh
        Bins
        Batch
    end

    methods (TestClassSetup)
        function projektPfad(testCase)
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture( ...
                fileparts(fileparts(mfilename('fullpath')))));
        end

        function beispieldaten(testCase)
            % Synthetischer Taylor-Flow: L_B nimmt entlang x leicht ab
            rng(1);
            n = 400;
            x = linspace(20, 140, n)';
            lb = 6.4 - 0.002 * x + 0.05 * randn(n, 1);
            luc = lb + 2.2;
            v = 0.32 + 0.01 * randn(n, 1);
            testCase.Roh = table(repmat((1:40)', 10, 1), x, v, lb, luc, luc - lb, lb ./ luc, ...
                'VariableNames', {'BubbleID', 'Position_X_mm', 'Speed_m_s', 'BubbleLength_mm', ...
                'UnitCellLength_mm', 'SlugLength_mm', 'VoidFraction'});
            mitten = (24:8:136)';
            m = numel(mitten);
            testCase.Bins = table(mitten, repmat(25, m, 1), 6.4 - 0.002 * mitten, repmat(0.05, m, 1), ...
                8.6 - 0.002 * mitten, repmat(0.04, m, 1), 0.32 + zeros(m, 1), repmat(0.01, m, 1), ...
                'VariableNames', {'BinCenter_mm', 'GroupCount', 'mean_BubbleLength_mm', 'std_BubbleLength_mm', ...
                'mean_UnitCellLength_mm', 'std_UnitCellLength_mm', 'mean_Speed_m_s', 'std_Speed_m_s'});
            b = [testCase.Bins; testCase.Bins];
            b.BinCenter_mm(m+1:end) = b.BinCenter_mm(m+1:end) + 300;
            b.CameraPosition = [ones(m, 1); 2 * ones(m, 1)];
            b.GasVelocity = repmat("0.198", 2*m, 1);
            b.LiquidVelocity = repmat("0.111", 2*m, 1);
            testCase.Batch = b;
            testCase.Stil = videoauswertung.plots.PlotStil(config());
        end
    end

    methods (Test)
        function allePlots(testCase, sprache)
            stil = testCase.Stil;
            stil.Sprache = sprache;
            figs = {videoauswertung.plots.plot_Geschwindigkeit_Laenge(testCase.Roh, stil), ...
                    videoauswertung.plots.plot_Laenge_Position(testCase.Roh, stil), ...
                    videoauswertung.plots.plot_Profil(testCase.Bins, stil), ...
                    videoauswertung.plots.plot_Verlauf(testCase.Batch, 'Speed_m_s', stil), ...
                    videoauswertung.plots.plot_Verlauf(testCase.Batch, 'BubbleLength_mm', stil)};
            erwartetX = [{stil.text('L_B')}, repmat({stil.text('position')}, 1, 4)];
            for k = 1:numel(figs)
                testCase.addTeardown(@() close(figs{k}));
                ax = findobj(figs{k}, 'Type', 'axes');
                testCase.verifyEqual(ax(1).XLabel.String, erwartetX{k});
            end
        end

        function speichernInFormaten(testCase)
            stil = testCase.Stil;
            stil.Formate = {'png', 'pdf'};
            ordner = testCase.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture).Folder;
            fig = videoauswertung.plots.plot_Profil(testCase.Bins, stil);
            testCase.addTeardown(@() close(fig));
            dateien = stil.speichere(fig, fullfile(ordner, 'profil'));
            testCase.verifyTrue(all(cellfun(@isfile, dateien)));
        end

        function unbekannteGroesseWirdAbgelehnt(testCase)
            testCase.verifyError(@() videoauswertung.plots.plot_Verlauf(testCase.Batch, 'Druck', testCase.Stil), ...
                'videoauswertung:plotGroesse');
        end
    end
end
