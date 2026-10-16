function zeige_Kalibrierung(ax, frame, info, px2mm, ok, sprache)
% ZEIGE_KALIBRIERUNG Kontrollbild der Maßstabsbestimmung.
%
% Gelb gestrichelt: Suchband; rote Kreuze: Linealstriche der verwendeten
% Kette; grüne Linie: gemessene Strecke. Titel: Maßstab, Strecke, Bildlänge.
%
% Parameter
% ---------
% ax : Achse
% frame : Grauwertbild des Kalibriervideos
% info, px2mm, ok : aus kalibriere_Massstab
% sprache : optional, 'de' (Standard) oder 'en' für den Titel

    if nargin < 6, sprache = 'de'; end
    t = videoauswertung.plots.PlotStil.texte();
    cla(ax);
    imshow(frame, [], 'Parent', ax);
    hold(ax, 'on');
    if ok
        rectangle(ax, 'Position', info.band, 'EdgeColor', 'y', 'LineStyle', '--', 'LineWidth', 1);
        plot(ax, info.striche_x, repmat(info.bestY, size(info.striche_x)), 'r+', 'MarkerSize', 8, 'LineWidth', 1.5);
        plot(ax, [info.erster_x, info.letzter_x], [info.bestY, info.bestY], 'go-', 'MarkerSize', 10, 'LineWidth', 2);
        title(ax, sprintf(t.kalib_titel.(sprache), px2mm, info.strecke_mm, info.bildlaenge_mm));
    else
        title(ax, t.kalib_fehl.(sprache), 'Color', 'r');
    end
    hold(ax, 'off');
    drawnow;
end
