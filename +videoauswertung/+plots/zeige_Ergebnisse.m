function zeige_Ergebnisse(resultsTable, statsTable, targetAxes)
% VISUALIZE_RESULTS Erstellt Diagramme zur Analyse von Blasenlaenge und Geschwindigkeit.
% Wenn targetAxes übergeben wird, wird nur der Längenabnahme-Plot dort hineingezeichnet.
% Ansonsten werden wie bisher separate figure()-Fenster geöffnet.
    if isempty(resultsTable) || height(resultsTable) == 0
        warning('Keine Daten zur Visualisierung in resultsTable vorhanden.');
        return;
    end
    % --- MODUS 1: Zeichnen in die App-GUI ---
    if nargin >= 3 && ~isempty(targetAxes) && isvalid(targetAxes)
        cla(targetAxes);
        % Löse alle fixen Seitenverhältnisse komplett auf
        axis(targetAxes, 'normal');
        set(targetAxes, 'DataAspectRatioMode', 'auto');
        set(targetAxes, 'PlotBoxAspectRatioMode', 'auto');
        set(targetAxes, 'YDir', 'normal');  % Stellt sicher, dass Y nicht mehr auf 'reverse' steht (von imagesc/axis image)
        
        % Wir zeichnen den wichtigsten Plot: Blasenlänge über Kanalposition
        scatter(targetAxes, resultsTable.Position_X_mm, resultsTable.BubbleLength_mm, 15, resultsTable.Speed_m_s, ...
            'filled', 'MarkerEdgeAlpha', 0.4, 'MarkerFaceAlpha', 0.4);
        
        colormap(targetAxes, 'jet');
        cb = colorbar(targetAxes);
        cb.Label.String = 'Velocity [m/s]';
        
        xlabel(targetAxes, 'Channel Position X [mm] (Distance from inlet)');
        ylabel(targetAxes, 'Bubble Length [mm]');
        title(targetAxes, 'Feedback: Bubble Length Decrease over Channel Length');
        grid(targetAxes, 'on');

        % Skalierung optimieren: tote Bereiche entfernen (X) und Stauchung beheben (Y)
        min_x = min(resultsTable.Position_X_mm);
        max_x = max(resultsTable.Position_X_mm);
        xlim(targetAxes, [min_x, max_x]);

        min_y = min(resultsTable.BubbleLength_mm);
        max_y = max(resultsTable.BubbleLength_mm);
        span_y = max_y - min_y;
        if span_y == 0
            padding = 0.5;
        else
            padding = 0.1 * span_y;
        end
        ylim(targetAxes, [max(0, min_y - padding), max_y + padding]);

        return; % Beende die Funktion hier, öffne keine neuen Fenster!
    end
    % --- MODUS 2: Standalone (Skript-Aufruf) ---
    figure('Name', 'Physikalische Analyse: Blasenlaenge & Geschwindigkeit', 'Position', [100, 100, 1200, 400]);
    subplot(1, 2, 1);
    scatter(resultsTable.BubbleLength_mm, resultsTable.Speed_m_s, 15, 'filled', ...
        'MarkerFaceColor', '#D95319', 'MarkerEdgeAlpha', 0.2, 'MarkerFaceAlpha', 0.2);
    if height(resultsTable) >= 2
        p = polyfit(resultsTable.BubbleLength_mm, resultsTable.Speed_m_s, 1);
        xFit = linspace(min(resultsTable.BubbleLength_mm), max(resultsTable.BubbleLength_mm), 100);
        hold on;
        plot(xFit, polyval(p, xFit), 'k--', 'LineWidth', 1.5);
        hold off;
    end
    xlabel('Local Bubble Length [mm]'); ylabel('Local Velocity [m/s]');
    title('Velocity vs. Bubble Length'); grid on;
    subplot(1, 2, 2);
    scatter(resultsTable.Position_X_mm, resultsTable.BubbleLength_mm, 15, resultsTable.Speed_m_s, ...
        'filled', 'MarkerEdgeAlpha', 0.4, 'MarkerFaceAlpha', 0.4);
    colormap('jet'); cb = colorbar; cb.Label.String = 'Velocity [m/s]';
    xlabel('Channel Position X [mm]'); ylabel('Bubble Length [mm]');
    title('Bubble length decrease over channel length'); grid on;
    if ~isempty(statsTable)
        figure('Name', 'Profile of Unit Cell and Bubble Length', 'Position', [150, 150, 800, 500]);
        hold on;
        errorbar(statsTable.BinCenter_mm, statsTable.mean_BubbleLength_mm, statsTable.std_BubbleLength_mm, ...
            '-o', 'LineWidth', 2, 'MarkerSize', 8, 'MarkerFaceColor', 'b', 'Color', 'b');
        errorbar(statsTable.BinCenter_mm, statsTable.mean_UnitCellLength_mm, statsTable.std_UnitCellLength_mm, ...
            '-s', 'LineWidth', 2, 'MarkerSize', 8, 'MarkerFaceColor', 'r', 'Color', 'r');
        xlabel('Channel Position X [mm]'); ylabel('Length [mm]');
        title('Profile of mean Bubble and Unit Cell Length');
        legend({'Bubble Length', 'Unit Cell Length'}, 'Location', 'best');
        grid on; hold off;
    end
end