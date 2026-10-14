function fig = plot_Verlauf(tab, groesse, stil, ax)
% PLOT_VERLAUF Verlauf einer Größe entlang des Kanals je Kameraposition.
%
% Für eine Einstellung (Gas-/Flüssigkeitsgeschwindigkeit, Material, Form,
% Kanal): Bin-Mittelwerte ± Standardabweichung, eine Linie je Kameraposition.
%
% Parameter
% ---------
% tab : Batch-Ergebnis (Zeilen einer Einstellung), Spalten CameraPosition,
%       BinCenter_mm, mean_/std_<Größe>
% groesse : 'Speed_m_s' oder 'BubbleLength_mm'
% stil : PlotStil
% ax : optional, Zielachse (sonst neue Figur)
%
% Rückgabe
% --------
% fig : Figur
%
% Beispiel
% --------
%   tab = readtable('output/Output_MassTransfer/Auswertung_Masse_....csv', 'Delimiter', ';', 'TextType', 'string');
%   sel = tab.GasVelocity == "0.198" & tab.LiquidVelocity == "0.111";
%   videoauswertung.plots.plot_Verlauf(tab(sel, :), 'Speed_m_s', videoauswertung.plots.PlotStil(config()));

    if nargin < 4, ax = []; end
    switch groesse
        case 'Speed_m_s',       yText = 'v';   tText = 'titel_verlauf_v';
        case 'BubbleLength_mm', yText = 'L_B'; tText = 'titel_verlauf_LB';
        otherwise, error('videoauswertung:plotGroesse', 'Unbekannte Größe: %s', groesse);
    end
    [fig, ax] = videoauswertung.plots.zielachse(stil, ax);
    hold(ax, 'on');
    % Eine Linie je Kameraposition und Aufnahme (mehrere Aufnahmen desselben
    % Messpunkts werden nicht zu einer Linie verbunden)
    if ismember('Aufnahme', tab.Properties.VariableNames)
        aufnahme = string(tab.Aufnahme);
    else
        aufnahme = strings(height(tab), 1);
    end
    [linien, ~, nr] = unique(table(tab.CameraPosition, aufnahme, 'VariableNames', {'pos', 'aufnahme'}), 'rows');
    mehrere = numel(unique(linien.aufnahme)) > 1;
    for k = 1:height(linien)
        if isnan(linien.pos(k)), continue; end
        sel = nr == k;
        [x, i] = sort(tab.BinCenter_mm(sel));
        y = tab.(['mean_' groesse])(sel);
        e = tab.(['std_' groesse])(sel);
        name = sprintf('%s %d', stil.text('kameraposition'), linien.pos(k));
        if mehrere
            name = sprintf('%s (%s)', name, linien.aufnahme(k));
        end
        errorbar(ax, x, y(i), e(i), 'o-', 'LineWidth', 1.2, 'MarkerSize', 4, 'DisplayName', name);
    end
    hold(ax, 'off');
    xlabel(ax, stil.text('position'));
    ylabel(ax, stil.text(yText));
    title(ax, sprintf('%s (%s %s m/s, %s %s m/s)', stil.text(tText), stil.text('gas'), ...
        tab.GasVelocity(1), stil.text('fluessig'), tab.LiquidVelocity(1)), 'Interpreter', 'none');
    legend(ax, 'Location', 'best');
    stil.formatiere(ax);
end
