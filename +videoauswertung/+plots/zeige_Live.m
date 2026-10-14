function zeige_Live(ax, I, seeds, det, px2mm, frame)
% ZEIGE_LIVE Zeichnet ein Frame mit Kanalrändern, Blasengrenzen und Blasenlänge.
%
% Rot: Kanalwände; grün/rot: linke/rechte Blasengrenze; magenta: Länge [mm].
%
% Parameter
% ---------
% ax : Achse (axes oder uiaxes)
% I : Grauwertbild
% seeds, det : aus erkenne_Blasen
% px2mm : Maßstab [mm/px]
% frame : Framenummer (Titel)

    [imgH, imgW] = size(I);
    cla(ax);
    imagesc(ax, I);
    colormap(ax, gray);
    title(ax, '');
    ylim(ax, [-80, imgH]);
    axis(ax, 'image');
    hold(ax, 'on');
    text(ax, imgW/2, -60, sprintf('Frame %d – Kanal- und Blasenerkennung', frame), ...
        'Color', 'k', 'FontWeight', 'bold', 'FontSize', 12, 'HorizontalAlignment', 'center');

    if isfield(seeds, 'y_top_line') && ~isempty(seeds.y_top_line)
        plot(ax, 1:length(seeds.y_top_line), seeds.y_top_line, 'r-', 'LineWidth', 1.5);
        plot(ax, 1:length(seeds.y_bot_line), seeds.y_bot_line, 'r-', 'LineWidth', 1.5);
        for d = 1:length(det)
            lx = det(d).leftX;
            rx = det(d).rightX;
            plot(ax, [lx, lx], [seeds.y_top_line(lx), seeds.y_bot_line(lx)], 'g-', 'LineWidth', 1.5);
            plot(ax, [rx, rx], [seeds.y_top_line(rx), seeds.y_bot_line(rx)], 'r-', 'LineWidth', 1.5);
            y_text = seeds.y_top_line(round((lx+rx)/2)) - 20;
            plot(ax, [lx, rx], [y_text+5, y_text+5], 'm-', 'LineWidth', 1);
            text(ax, (lx+rx)/2, y_text, sprintf('%.2f\nmm', (rx - lx) * px2mm), ...
                'Color', 'm', 'FontWeight', 'bold', 'HorizontalAlignment', 'center', 'FontSize', 14);
        end
    end
    hold(ax, 'off');
    drawnow;
end
