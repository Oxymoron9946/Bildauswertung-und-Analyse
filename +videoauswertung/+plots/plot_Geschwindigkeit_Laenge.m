function fig = plot_Geschwindigkeit_Laenge(rohdaten, stil, ax)
% PLOT_GESCHWINDIGKEIT_LAENGE Blasengeschwindigkeit über Blasenlänge mit linearer Anpassung.
%
% Zeigt, ob längere Blasen schneller sind (Steigung der Anpassung).
%
% Parameter
% ---------
% rohdaten : table aus berechne_Physik (BubbleLength_mm, Speed_m_s)
% stil : PlotStil
% ax : optional, Zielachse (sonst neue Figur)
%
% Rückgabe
% --------
% fig : Figur

    if nargin < 3, ax = []; end
    [fig, ax] = videoauswertung.plots.zielachse(stil, ax);
    scatter(ax, rohdaten.BubbleLength_mm, rohdaten.Speed_m_s, 12, 'filled', ...
        'MarkerFaceAlpha', 0.25, 'DisplayName', stil.text('messpunkte'));
    if height(rohdaten) >= 2
        p = polyfit(rohdaten.BubbleLength_mm, rohdaten.Speed_m_s, 1);
        x = linspace(min(rohdaten.BubbleLength_mm), max(rohdaten.BubbleLength_mm), 100);
        hold(ax, 'on');
        plot(ax, x, polyval(p, x), 'k--', 'LineWidth', 1.2, 'DisplayName', stil.text('anpassung'));
        hold(ax, 'off');
    end
    xlabel(ax, stil.text('L_B'));
    ylabel(ax, stil.text('v'));
    title(ax, stil.text('titel_v_LB'));
    legend(ax, 'Location', 'best');
    stil.formatiere(ax);
end
