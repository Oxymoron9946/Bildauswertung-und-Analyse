function exportiere_Methodik(I, B_vorher, B_nachher, seeds, det, px2mm, cfg)
% EXPORTIERE_METHODIK Speichert die Bildverarbeitungsschritte eines Frames als PNG.
%
% Abb1 Original, Abb2 Kontrast (CLAHE + Median), Abb3 Binärbild,
% Abb5 Kanalgeometrie, Abb6 Raycasting/Kantentypen, Abb7 Region-Growing-Maske,
% Abb8 gefülltes Binärbild, Abb9 Bemaßung der Blasen [mm].
% Ziel: cfg.pfade.abbildungen, Auflösung cfg.abbildungen.dpi.
%
% Parameter
% ---------
% I : Grauwertbild
% B_vorher, B_nachher, seeds, det : aus erkenne_Blasen
% px2mm : Maßstab [mm/px]
% cfg : struct aus config()

    ziel = cfg.pfade.abbildungen;
    if ~isfolder(ziel)
        mkdir(ziel);
    end
    fprintf('\n--- Exportiere Abbildungen für Frame %d nach %s ---\n', cfg.abbildungen.frame, ziel);
    fig = figure('Visible', 'off', 'Position', [100, 100, 1200, 400]);
    aufraeumen = onCleanup(@() close(fig));
    ax = axes(fig);
    speichere = @(name) exportgraphics(fig, fullfile(ziel, name), 'Resolution', cfg.abbildungen.dpi);

    imshow(I, 'Parent', ax);
    speichere('Abb1_Original.png');

    imshow(seeds.I_eq, 'Parent', ax);
    speichere('Abb2_Kontrast.png');

    imshow(B_vorher, 'Parent', ax);
    speichere('Abb3_Binaer.png');

    imshow(seeds.B_clean, 'Parent', ax);
    hold(ax, 'on');
    plot(ax, 1:length(seeds.mid_line_y), seeds.mid_line_y, 'c-', 'LineWidth', 1.5);
    plot(ax, 1:length(seeds.y_top_line), seeds.y_top_line, 'r-', 'LineWidth', 1.5);
    plot(ax, 1:length(seeds.y_bot_line), seeds.y_bot_line, 'r-', 'LineWidth', 1.5);
    hold(ax, 'off');
    speichere('Abb5_Kanalgeometrie.png');

    imshow(seeds.B_clean, 'Parent', ax);
    hold(ax, 'on');
    for i = 1:3:length(seeds.ray_x)   % jeder dritte Strahl
        plot(ax, [seeds.ray_x(i), seeds.ray_x(i)], [seeds.ray_y0(i), seeds.ray_y1(i)], 'm-', 'LineWidth', 0.5);
    end
    plot(ax, seeds.slug_cx, seeds.slug_cy, 'g.', 'MarkerSize', 8);
    plot(ax, seeds.bub_cx, seeds.bub_cy, 'r.', 'MarkerSize', 8);
    plot(ax, seeds.tie_cx, seeds.tie_cy, 'c.', 'MarkerSize', 8);
    hold(ax, 'off');
    speichere('Abb6_Raycasting_Kanten.png');

    imshow(seeds.Mask, 'Parent', ax);
    hold(ax, 'on');
    plot(ax, [seeds.bub_cx, seeds.slug_cx], [seeds.bub_cy, seeds.slug_cy], '.', 'Color', [1 0.5 0], 'MarkerSize', 8);
    [y_s, x_s] = find(seeds.Marker);
    plot(ax, x_s, y_s, 'b.', 'MarkerSize', 8);
    hold(ax, 'off');
    speichere('Abb7_RegionGrowing_Maske.png');

    imshow(B_nachher, 'Parent', ax);
    speichere('Abb8_Gefuellt.png');

    imshow(I, 'Parent', ax);
    hold(ax, 'on');
    for j = 1:numel(det)
        % Linien 1 px außerhalb, damit sie im Slug liegen
        x_l = det(j).leftX - 1;
        x_r = det(j).rightX + 1;
        y = det(j).leftY;
        y_mass = y - cfg.abbildungen.bemassung_px;
        plot(ax, [x_l, x_l], [y, y_mass], 'm:', 'LineWidth', 0.5);
        plot(ax, [x_r, x_r], [y, y_mass], 'm:', 'LineWidth', 0.5);
        plot(ax, [x_l, x_r], [y_mass, y_mass], 'm-', 'LineWidth', 1.0);
        text(ax, (x_l+x_r)/2, y_mass-15, sprintf('%.2f\nmm', (det(j).rightX - det(j).leftX) * px2mm), ...
            'Color', 'm', 'FontWeight', 'bold', 'HorizontalAlignment', 'center', 'FontSize', 10);
    end
    hold(ax, 'off');
    speichere('Abb9_FinaleMessung.png');
    fprintf('Export abgeschlossen.\n\n');
end
