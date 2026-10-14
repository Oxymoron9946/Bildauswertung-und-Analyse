function fig = plot_Profil(bins, stil, ax)
% PLOT_PROFIL Mittlere Blasen- und Unit-Cell-Länge je Bin (± Standardabweichung).
%
% Parameter
% ---------
% bins : table aus berechne_Physik bzw. Ergebnis-CSV (BinCenter_mm,
%        mean_/std_BubbleLength_mm, mean_/std_UnitCellLength_mm)
% stil : PlotStil
% ax : optional, Zielachse (sonst neue Figur)
%
% Rückgabe
% --------
% fig : Figur

    if nargin < 3, ax = []; end
    [fig, ax] = videoauswertung.plots.zielachse(stil, ax);
    [x, i] = sort(bins.BinCenter_mm);
    errorbar(ax, x, bins.mean_BubbleLength_mm(i), bins.std_BubbleLength_mm(i), '-o', ...
        'LineWidth', 1.2, 'MarkerSize', 5, 'DisplayName', stil.text('L_B'));
    hold(ax, 'on');
    errorbar(ax, x, bins.mean_UnitCellLength_mm(i), bins.std_UnitCellLength_mm(i), '-s', ...
        'LineWidth', 1.2, 'MarkerSize', 5, 'DisplayName', stil.text('L_UC'));
    hold(ax, 'off');
    xlabel(ax, stil.text('position'));
    ylabel(ax, stil.text('laenge'));
    title(ax, stil.text('titel_profil'));
    legend(ax, 'Location', 'best');
    stil.formatiere(ax);
end
