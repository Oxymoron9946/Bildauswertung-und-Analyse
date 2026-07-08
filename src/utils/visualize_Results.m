function visualize_Results(resultsTable, statsTable, targetAxes)
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
        
        % Wir zeichnen den wichtigsten Plot: Blasenlänge über Kanalposition
        scatter(targetAxes, resultsTable.Position_X_mm, resultsTable.BubbleLength_mm, 15, resultsTable.Speed_m_s, ...
            'filled', 'MarkerEdgeAlpha', 0.4, 'MarkerFaceAlpha', 0.4);
        
        colormap(targetAxes, 'jet');
        cb = colorbar(targetAxes);
        cb.Label.String = 'Geschwindigkeit [m/s]';
        
        xlabel(targetAxes, 'Kanalposition X [mm] (Distanz ab Einlass)');
        ylabel(targetAxes, 'Blasenlaenge [mm]');
        title(targetAxes, 'Feedback: Blasenlaengenabnahme ueber Kanallaenge');
        grid(targetAxes, 'on');
        
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
    xlabel('Lokale Blasenlaenge [mm]'); ylabel('Lokale Geschwindigkeit [m/s]');
    title('Geschwindigkeit vs. Blasenlaenge'); grid on;
    subplot(1, 2, 2);
    scatter(resultsTable.Position_X_mm, resultsTable.BubbleLength_mm, 15, resultsTable.Speed_m_s, ...
        'filled', 'MarkerEdgeAlpha', 0.4, 'MarkerFaceAlpha', 0.4);
    colormap('jet'); cb = colorbar; cb.Label.String = 'Geschwindigkeit [m/s]';
    xlabel('Kanalposition X [mm]'); ylabel('Blasenlaenge [mm]');
    title('Blasenlaengenabnahme ueber Kanallaenge'); grid on;
    if ~isempty(statsTable)
        figure('Name', 'Verlauf der Unit-Cell und Blasenlaenge', 'Position', [150, 150, 800, 500]);
        hold on;
        errorbar(statsTable.BinCenter_mm, statsTable.mean_BubbleLength_mm, statsTable.std_BubbleLength_mm, ...
            '-o', 'LineWidth', 2, 'MarkerSize', 8, 'MarkerFaceColor', 'b', 'Color', 'b');
        errorbar(statsTable.BinCenter_mm, statsTable.mean_UnitCellLength_mm, statsTable.std_UnitCellLength_mm, ...
            '-s', 'LineWidth', 2, 'MarkerSize', 8, 'MarkerFaceColor', 'r', 'Color', 'r');
        xlabel('Kanalposition X [mm]'); ylabel('Laenge [mm]');
        title('Verlauf der mittleren Blasen- und Unit-Cell-Laenge');
        legend({'Blasenlaenge', 'Unit-Cell Laenge'}, 'Location', 'best');
        grid on; hold off;
    end
end