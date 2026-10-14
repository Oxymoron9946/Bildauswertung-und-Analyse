classdef test_Regression < matlab.unittest.TestCase
% TEST_REGRESSION Vergleicht die Ergebnisse mit der eingefrorenen Referenz.
%
% Die Referenz in tests/referenz/ stammt aus dem Stand 0cf713b (Baseline)
% bzw. aus dem letzten freigegebenen Fix (siehe docs/CHANGELOG.md).
% Verglichen werden alle Spalten der Referenz Wert für Wert ohne Toleranz.
% Spalten, die bewusst gestrichen wurden, stehen in GESTRICHEN.
%
% Die Videos sind nicht im Repository. Fehlen sie, wird der Test
% übersprungen (assumeTrue), nicht als Fehler gewertet.
%
% Laufzeit: ca. 10 min (ein Batch-Ordner mit 15 Videos, 4 Einzelvideos).

    properties (Constant)
        % Bewusst entfernte Spalten (Gate Phase 1, C10): redundant zu GroupCount
        GESTRICHEN = {'numel_BubbleLength_mm', 'numel_UnitCellLength_mm', ...
            'numel_SlugLength_mm', 'numel_VoidFraction', 'numel_Speed_m_s'};
    end

    properties (TestParameter)
        fall = test_Regression.faelle();
    end

    methods (Static)
        function f = faelle()
            f = struct( ...
                'batch_PVC_1500_1150', struct('art', 'batch', 'ziel', 'PVC_1500_1150', ...
                    'referenz', 'batch/PVC_1500_1150'), ...
                'einzel_PTFE_Masse', struct('art', 'einzel', 'ziel', ...
                    'PTFE_1000_600/Auswertung_20_CO2/Pos_1_Kal_1/0.198_0.111_Pos_1_R_1000_PTFE_600/200fps_001', ...
                    'referenz', 'gui_einzel/Output_MassTransfer/Analysis_Mass_0.198_0.111_Pos_1_R_1000_PTFE_600.csv'), ...
                'einzel_Glas_Druck', struct('art', 'einzel', 'ziel', ...
                    'Glaskanal/Druck/Pos_1_Kal_2/0.198_0.167_Pos_1_Q_1000_Glas_600_Druck/200fps_001', ...
                    'referenz', 'gui_einzel/Output_PressureCalibration/Analysis_Pressure_0.198_0.167_Pos_1_Q_1000_Glas_600_Druck.csv'), ...
                'einzel_PVC1000_Pos3', struct('art', 'einzel', 'ziel', ...
                    'PVC_1000_600/Auswertung_20_CO2/Auswertung_20_CO2/Pos_3_Kal_1/0.186_0.111_Pos_3_R_1000_PVC_600/200fps_001', ...
                    'referenz', 'gui_einzel/Output_MassTransfer/Analysis_Mass_0.186_0.111_Pos_3_R_1000_PVC_600.csv'), ...
                'einzel_PVC1500_Druck', struct('art', 'einzel', 'ziel', ...
                    'PVC_1500_1150/Druck/Pos_1_Kal_3/0.198_0.111_Pos_1_R_1500_PVC_1150_Druck/200fps_001', ...
                    'referenz', 'gui_einzel/Output_PressureCalibration/Analysis_Pressure_0.198_0.111_Pos_1_R_1500_PVC_1150_Druck.csv'));
        end
    end

    methods (TestClassSetup)
        function projektPfad(testCase)
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture( ...
                fileparts(fileparts(mfilename('fullpath')))));
        end
    end

    methods (Test)
        function ergebnisGleichReferenz(testCase, fall)
            cfg = config();
            ziel = fullfile(cfg.pfade.messdaten, fall.ziel);
            testCase.assumeTrue(isfolder(ziel), sprintf('Messdaten fehlen: %s', ziel));

            ausgabe = tempname;
            mkdir(ausgabe);
            testCase.addTeardown(@() rmdir(ausgabe, 's'));
            neu = fuehre_Regressionslauf(fall.art, ziel, ausgabe);

            refDatei = fullfile(fileparts(mfilename('fullpath')), 'referenz', fall.referenz);
            if isfolder(refDatei)
                refDatei = dir(fullfile(refDatei, '**', '*.csv'));
                testCase.assertNumElements(refDatei, 1, 'Referenzordner muss genau eine CSV enthalten.');
                refDatei = fullfile(refDatei.folder, refDatei.name);
            end
            ref = lies_Ergebnis(refDatei);
            vergleiche(testCase, ref, neu, test_Regression.GESTRICHEN);
        end
    end
end

function T = lies_Ergebnis(datei)
    % Trennzeichen automatisch (Batch: Semikolon, alte GUI-Einzel-CSV: Komma).
    % Zahlen werden als Text gelesen und mit str2double verglichen, damit
    % die Darstellung der Referenz nicht durch das Einlesen gerundet wird.
    opts = detectImportOptions(datei, 'TextType', 'string', 'VariableNamingRule', 'preserve');
    opts = setvartype(opts, 'string');
    T = readtable(datei, opts);
end

function vergleiche(testCase, ref, neu, gestrichen)
    testCase.assertEqual(height(neu), height(ref), 'Zeilenanzahl weicht ab.');
    for name = string(ref.Properties.VariableNames)
        if any(name == gestrichen)
            continue;
        end
        testCase.assertTrue(any(name == string(neu.Properties.VariableNames)), ...
            sprintf('Spalte %s fehlt im neuen Ergebnis.', name));
        r = ref.(name);
        n = neu.(name);
        if isnumeric(n)
            n = compose('%.17g', n);
        end
        n = string(n);
        rz = str2double(r);
        nz = str2double(n);
        istZahl = ~isnan(rz) | ~isnan(nz);
        abw = find(istZahl & ~(rz == nz | (isnan(rz) & isnan(nz))), 1);
        testCase.verifyEmpty(abw, sprintf('Spalte %s, Zeile %d: Referenz %s, neu %s', ...
            name, abw, r(max([abw 1])), n(max([abw 1]))));
        abwText = find(~istZahl & r ~= n, 1);
        testCase.verifyEmpty(abwText, sprintf('Spalte %s, Zeile %d: Referenz "%s", neu "%s"', ...
            name, abwText, r(max([abwText 1])), n(max([abwText 1]))));
    end
end
