function visualize_Results(resultsTable, statsTable)
% VISUALIZE_RESULTS Erstellt Diagramme zur Analyse von Blasenlaenge und Geschwindigkeit

%% 1. Abbruchbedingung bei leeren Daten
if isempty(resultsTable) || height(resultsTable) == 0
    warning('Keine Daten zur Visualisierung in resultsTable vorhanden.');
    return;
end

%% 2. Hauptfigur: Physikalische Analyse (Laenge & Geschwindigkeit)
figure('Name', 'Physikalische Analyse: Blasenlaenge & Geschwindigkeit', 'Position', [100, 100, 1200, 400]);

% --- Subplot 1: Geschwindigkeit vs. Blasenlaenge ---
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

xlabel('Lokale Blasenlaenge [mm]');
ylabel('Lokale Geschwindigkeit [m/s]');
title('Geschwindigkeit vs. Blasenlaenge');
grid on;

% --- Subplot 2: Laengenabnahme ueber die Kanallaenge ---
subplot(1, 2, 2);
scatter(resultsTable.Position_X_mm, resultsTable.BubbleLength_mm, 15, resultsTable.Speed_m_s, ...
    'filled', 'MarkerEdgeAlpha', 0.4, 'MarkerFaceAlpha', 0.4);

colormap('jet');
cb = colorbar;
cb.Label.String = 'Geschwindigkeit [m/s]';
xlabel('Kanalposition X [mm] (Distanz ab Einlass)');
ylabel('Blasenlaenge [mm]');
title('Blasenlaengenabnahme ueber Kanallaenge');
grid on;

%% 3. Zusatzfigur: Statistik-Verlauf der Laengen
if ~isempty(statsTable)
    figure('Name', 'Verlauf der Unit-Cell und Blasenlaenge', 'Position', [150, 150, 800, 500]);
    hold on;
    
    % Blasenlänge
    errorbar(statsTable.BinCenter_mm, statsTable.mean_BubbleLength_mm, statsTable.std_BubbleLength_mm, ...
        '-o', 'LineWidth', 2, 'MarkerSize', 8, 'MarkerFaceColor', 'b', 'Color', 'b');
    
    % Unit-Cell Länge
    errorbar(statsTable.BinCenter_mm, statsTable.mean_UnitCellLength_mm, statsTable.std_UnitCellLength_mm, ...
        '-s', 'LineWidth', 2, 'MarkerSize', 8, 'MarkerFaceColor', 'r', 'Color', 'r');

    xlabel('Kanalposition X [mm] (Distanz ab Eintritt)');
    ylabel('Laenge [mm]');
    title('Verlauf der mittleren Blasen- und Unit-Cell-Laenge');
    legend({'Blasenlaenge', 'Unit-Cell Laenge'}, 'Location', 'best');
    grid on; hold off;
end
end
