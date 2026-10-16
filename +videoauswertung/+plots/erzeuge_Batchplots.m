function dateien = erzeuge_Batchplots(csv, stil)
% ERZEUGE_BATCHPLOTS Verlaufsplots je Einstellung aus einer Batch-Ergebnisdatei.
%
% Je Kombination aus Gas- und Flüssigkeitsgeschwindigkeit, Material,
% Geometrie und Kanal entstehen zwei Plots (Geschwindigkeit,
% Blasenlänge) im Unterordner "plots" neben der CSV:
%   plots/Gas_<jG>_Liq_<jL>_<Material>_<Form>_<Kanal>um_Geschwindigkeit.png/.pdf
%   plots/Gas_<jG>_Liq_<jL>_<Material>_<Form>_<Kanal>um_Blasenlaenge.png/.pdf
%
% Parameter
% ---------
% csv : Batch-Ergebnisdatei (Semikolon)
% stil : PlotStil
%
% Rückgabe
% --------
% dateien : cellstr der geschriebenen Bilddateien

    tab = videoauswertung.plots.lies_Batchergebnis(csv);
    ordner = fullfile(fileparts(csv), 'plots');
    dateien = {};
    kombis = unique(tab(:, {'GasVelocity', 'LiquidVelocity', 'Material', 'Geometrie', 'Kanal_um'}), 'rows');
    for k = 1:height(kombis)
        kb = kombis(k, :);
        if ismissing(kb.GasVelocity) || kb.GasVelocity == "NaN"
            continue;
        end
        sel = tab.GasVelocity == kb.GasVelocity & tab.LiquidVelocity == kb.LiquidVelocity & ...
              tab.Material == kb.Material & tab.Geometrie == kb.Geometrie & tab.Kanal_um == kb.Kanal_um;
        name = sprintf('Gas_%s_Liq_%s_%s_%s_%dum', kb.GasVelocity, kb.LiquidVelocity, ...
            kb.Material, kb.Geometrie, kb.Kanal_um);
        for g = {'Speed_m_s', 'Geschwindigkeit'; 'BubbleLength_mm', 'Blasenlaenge'}'
            fig = stil.neue_Figur('off');
            videoauswertung.plots.plot_Verlauf(tab(sel, :), g{1}, stil, axes(fig));
            dateien = [dateien, stil.speichere(fig, fullfile(ordner, [name '_' g{2}]))]; %#ok<AGROW>
            close(fig);
        end
    end
    fprintf('%d Verlaufsplots in %s\n', numel(dateien), ordner);
end

