function [fig, ax] = zielachse(stil, ax)
% ZIELACHSE Gegebene Achse leeren oder neue Figur im Plotstil anlegen.
%
% Parameter
% ---------
% stil : PlotStil
% ax : Achse (axes/uiaxes) oder [] für eine neue Figur
%
% Rückgabe
% --------
% fig, ax : Figur und Achse zum Zeichnen

    if ~isempty(ax)
        cla(ax, 'reset');
        fig = ancestor(ax, 'figure');
    else
        fig = stil.neue_Figur();
        ax = axes(fig);
    end
end
