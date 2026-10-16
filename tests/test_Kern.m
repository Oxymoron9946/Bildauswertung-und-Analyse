classdef test_Kern < matlab.unittest.TestCase
% TEST_KERN Einheitentests der Kernfunktionen ohne Videos.

    properties
        Cfg
        Ordner
    end

    methods (TestClassSetup)
        function projektPfad(testCase)
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture( ...
                fileparts(fileparts(mfilename('fullpath')))));
        end
    end

    methods (TestMethodSetup)
        function vorbereiten(testCase)
            testCase.Cfg = config();
            testCase.Ordner = testCase.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture).Folder;
        end
    end

    methods (Test)
        %% lies_Messlauf
        function messlaufMitAufnahme(testCase)
            v = fullfile('X', 'Pos_1_Kal_1', '0.198_0.111_Pos_1_R_1000_PTFE_600', '200fps_002', 'cam.avi');
            m = videoauswertung.kern.lies_Messlauf(v);
            testCase.verifyEqual(m.name, '0.198_0.111_Pos_1_R_1000_PTFE_600');
            testCase.verifyEqual(m.aufnahme, "200fps_002");
            testCase.verifyEqual(m.gruppe, 'Pos_1_Kal_1');
            testCase.verifyEqual(m.fps, 200);
            testCase.verifyEqual([m.gas m.liq m.form m.material], ["0.198" "0.111" "R" "PTFE"]);
            testCase.verifyEqual([m.kanal m.nadel], ["1000" "600"]);
            testCase.verifyEqual(m.messart, "Massentransfer");
        end

        function messlaufDruckOhneAufnahme(testCase)
            v = fullfile('X', 'Pos_3_Kal_1', '0.07_0.111_Pos_3_R_1500_PVC_1150_Druck', 'cam.avi');
            m = videoauswertung.kern.lies_Messlauf(v);
            testCase.verifyEqual(m.name, '0.07_0.111_Pos_3_R_1500_PVC_1150_Druck');
            testCase.verifyEqual(m.aufnahme, "");
            testCase.verifyTrue(isnan(m.fps));
            testCase.verifyEqual(m.messart, "Druckkalibrierung");
        end

        function messlaufOhneSchema(testCase)
            m = videoauswertung.kern.lies_Messlauf(fullfile('X', '0,07_0,04_Position_1', '500fps_001', 'cam.avi'));
            testCase.verifyFalse(m.schema);
            testCase.verifyEqual(m.gruppe, '');
            testCase.verifyEqual(m.gas, "NaN");
        end

        %% einlauflaenge
        function einlauflaengeWasser(testCase)
            % j = 0.3 m/s, d = 1 mm: Re = 1000*0.3*0.001/0.001 = 300, L = 0.05*300*1 mm = 15 mm
            m = struct('gas', "0.2", 'liq', "0.1", 'kanal', "1000");
            testCase.verifyEqual(videoauswertung.kern.einlauflaenge(m, testCase.Cfg), 15, 'AbsTol', 1e-12);
            m.gas = "NaN";
            testCase.verifyTrue(isnan(videoauswertung.kern.einlauflaenge(m, testCase.Cfg)));
        end

        %% finde_Kalibrierung
        function kalibrierungImGruppenordner(testCase)
            gruppe = fullfile(testCase.Ordner, 'Messreihe', 'Pos_3_Kal_1');
            kalib = lege_an(fullfile(gruppe, 'Kalibrierung_1_Pos_3', 'k.avi'));
            video = lege_an(fullfile(gruppe, '0.1_0.1_Pos_3_R_1000_PVC_600', '200fps_001', 'v.avi'));
            % gleichnamige Gruppe in einem anderen Teilordner darf nicht stören
            lege_an(fullfile(testCase.Ordner, 'Druck', 'Pos_3_Kal_1', 'Kalibrierung_1_Pos_3_x', 'k.avi'));
            testCase.verifyEqual(videoauswertung.kern.finde_Kalibrierung(video, testCase.Cfg), kalib);
        end

        function mehrdeutigeKalibrierungIstFehler(testCase)
            gruppe = fullfile(testCase.Ordner, 'Pos_1_Kal_1');
            lege_an(fullfile(gruppe, 'Kalibrierung_1', 'k.avi'));
            lege_an(fullfile(gruppe, 'Kalibrierung_2', 'k.avi'));
            video = lege_an(fullfile(gruppe, '0.1_0.1_Pos_1_R_1000_PVC_600', 'v.avi'));
            testCase.verifyError(@() videoauswertung.kern.finde_Kalibrierung(video, testCase.Cfg), ...
                'videoauswertung:mehrdeutigeKalibrierung');
        end

        function fehlendeGruppeIstFehler(testCase)
            video = lege_an(fullfile(testCase.Ordner, '0.1_0.1_Position_1', 'v.avi'));
            testCase.verifyError(@() videoauswertung.kern.finde_Kalibrierung(video, testCase.Cfg), ...
                'videoauswertung:keineGruppe');
        end

        %% lies_Laborbuchzeile
        function laborbuchPflichtangaben(testCase)
            labor = laborbuch(101300, 22, 0.2, 72, 181.5);
            z = videoauswertung.kern.lies_Laborbuchzeile(labor, struct('name', 'lauf_a'));
            testCase.verifyEqual([z.p_Pa z.temp_C z.co2 z.reaktor_cm z.offset_mm], [101300 22 0.2 72 181.5]);
        end

        function laborbuchFehlendeZeileOderAngabe(testCase)
            labor = laborbuch(101300, NaN, 0.2, 72, 0);
            testCase.verifyError(@() videoauswertung.kern.lies_Laborbuchzeile(labor, struct('name', 'gibt_es_nicht')), ...
                'videoauswertung:laborbuch');
            testCase.verifyError(@() videoauswertung.kern.lies_Laborbuchzeile(labor, struct('name', 'lauf_a')), ...
                'videoauswertung:laborbuch');
        end

        %% exportiere_Batch
        function exportJeSetup(testCase)
            a = ergebnis("PTFE", 0.2, "Massentransfer");
            b = ergebnis("PVC", 0.2, "Massentransfer");
            c = ergebnis("PVC", 0, "Druckkalibrierung");
            dateien = videoauswertung.io.exportiere_Batch({a, table(), b, c}, testCase.Ordner);
            [~, namen] = cellfun(@fileparts, dateien, 'UniformOutput', false);
            testCase.verifyEqual(sort(namen), sort({'Auswertung_Masse_PTFE_R_1000um_72cm_20molCO2_600um', ...
                'Auswertung_Masse_PVC_R_1000um_72cm_20molCO2_600um', 'Auswertung_Druck_PVC_R_1000um_72cm_0molCO2_600um'}));
        end

        %% Laufconfig
        function laufconfigHinUndZurueck(testCase)
            cfg = testCase.Cfg;
            cfg.pfade.ausgabe = testCase.Ordner;
            cfg.detektion.sens = [0.85 0.9 0.95];
            cfg.plots.sprache = 'en';
            datei = videoauswertung.io.schreibe_Laufconfig(cfg, 'einzel', 'video.avi');
            [geladen, lauf] = videoauswertung.io.lade_Laufconfig(datei);
            testCase.verifyEqual(geladen, cfg);
            testCase.verifyEqual(lauf.art, 'einzel');
            testCase.verifyEqual(lauf.ziel, 'video.avi');
        end
    end
end

function datei = lege_an(datei)
    if ~isfolder(fileparts(datei)), mkdir(fileparts(datei)); end
    fclose(fopen(datei, 'w'));
end

function T = laborbuch(p, t, co2, L, offset)
    T = table("lauf_a", p, t, co2, L, offset, 'VariableNames', ...
        {'Dateiname', 'Umgebungsdruck', 'Umgebungstemperatur', 'CO2-Anteil', 'Kanallaenge', 'Offset'});
end

function T = ergebnis(material, co2, messart)
    T = table("0.1", "0.1", 1, "200fps_001", material, "R", 1000, 600, 72, 101300, 22, co2, messart, 0.95, ...
        10, 50, 6.4, 0.1, 'VariableNames', {'GasVelocity', 'LiquidVelocity', 'CameraPosition', 'Aufnahme', ...
        'Material', 'Geometrie', 'Kanal_um', 'Nadel_um', 'Reaktor_cm', 'Druck_Pa_Auslass', 'Temperatur_C', ...
        'CO2_Anteil', 'Messart', 'UsedSensitivity', 'BinCenter_mm', 'GroupCount', ...
        'mean_BubbleLength_mm', 'std_BubbleLength_mm'});
end
