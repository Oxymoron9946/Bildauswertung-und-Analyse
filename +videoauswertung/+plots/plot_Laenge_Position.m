function fig = plot_Laenge_Position(rohdaten, stil, ax)
% PLOT_LAENGE_POSITION Blasenlänge entlang des Kanals, Farbe = Geschwindigkeit.
%
% Jeder Punkt ist ein Messwert zwischen zwei Frames. Eine Abnahme der
% Blasenlänge entlang x zeigt den Stoffübergang (CO2 löst sich).
%
% Parameter
% ---------
% rohdaten : table aus berechne_Physik (Position_X_mm, BubbleLength_mm, Speed_m_s)
% stil : PlotStil
% ax : optional, Zielachse (sonst neue Figur), z. B. die Achse der GUI
%
% Rückgabe
% --------
% fig : Figur

    if nargin < 3, ax = []; end
    [fig, ax] = videoauswertung.plots.zielachse(stil, ax);
    scatter(ax, rohdaten.Position_X_mm, rohdaten.BubbleLength_mm, 12, rohdaten.Speed_m_s, ...
        'filled', 'MarkerFaceAlpha', 0.4);
    colormap(ax, parula);
    cb = colorbar(ax);
    cb.Label.String = stil.text('v');
    xlabel(ax, stil.text('position'));
    ylabel(ax, stil.text('L_B'));
    title(ax, stil.text('titel_LB_x'));
    xlim(ax, [min(rohdaten.Position_X_mm), max(rohdaten.Position_X_mm)] + [-1 1]);
    stil.formatiere(ax);
end
