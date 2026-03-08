function visualize_Results(resultsTable, statsTable)
    if isempty(resultsTable) || height(resultsTable) == 0, return; end

    figure('Name', 'Physikalische Analyse: Volumen & Geschwindigkeit', 'Position', [100, 100, 1200, 400]);

    subplot(1, 2, 1);
    scatter(resultsTable.Volume_ul, resultsTable.Speed_m_s, 15, 'filled', 'MarkerFaceColor', '#D95319', 'MarkerEdgeAlpha', 0.2, 'MarkerFaceAlpha', 0.2);
    p = polyfit(resultsTable.Volume_ul, resultsTable.Speed_m_s, 1);
    xFit = linspace(min(resultsTable.Volume_ul), max(resultsTable.Volume_ul), 100);
    hold on; plot(xFit, polyval(p, xFit), 'k--', 'LineWidth', 1.5); hold off;
    xlabel('Lokales Blasenvolumen [\muL]'); ylabel('Lokale Geschwindigkeit [m/s]');
    title('Geschwindigkeit vs. Echtes Volumen'); grid on;

    subplot(1, 2, 2);
    scatter(resultsTable.Position_X_mm, resultsTable.Volume_ul, 15, resultsTable.Speed_m_s, 'filled', 'MarkerEdgeAlpha', 0.4, 'MarkerFaceAlpha', 0.4);
    colormap('jet'); cb = colorbar; cb.Label.String = 'Geschwindigkeit [m/s]';
    xlabel('Kanalposition X [mm] (Distanz ab Einlass)');
    ylabel('Blasenvolumen [\muL]');
    title('Volumenabnahme über Kanallänge'); grid on;

    if ~isempty(statsTable) && ismember('Expected_Speed_m_s', statsTable.Properties.VariableNames)
        figure('Name', 'Validierung der Zweiphasen-Geschwindigkeit', 'Position', [150, 150, 800, 500]);
        
        plot(statsTable.BinCenter_mm, statsTable.mean_Speed_m_s, '-o', 'LineWidth', 2, 'MarkerSize', 8, 'MarkerFaceColor', 'b');
        hold on;
        plot(statsTable.BinCenter_mm, statsTable.Expected_Speed_m_s, '--s', 'LineWidth', 2, 'MarkerSize', 8, 'MarkerFaceColor', 'r', 'Color', 'r');
        errorbar(statsTable.BinCenter_mm, statsTable.mean_Speed_m_s, statsTable.std_Speed_m_s, 'b', 'LineStyle', 'none', 'LineWidth', 1);
        
        xlabel('Kanalposition X [mm] (Distanz ab Eintritt)');
        ylabel('Zweiphasen-Geschwindigkeit v_{tp} [m/s]');
        title('Vergleich: Gemessene vs. Erwartete Geschwindigkeitsabnahme');
        legend('Gemessen (Bildauswertung)', 'Erwartet (aus Volumenverlust berechnet)', 'Location', 'best');
        grid on; hold off;
    end
end
