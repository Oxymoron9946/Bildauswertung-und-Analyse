function visualize_Results(resultsTable, statsTable)
% VISUALIZE_RESULTS Erstellt Diagramme zur Analyse von Volumen und Geschwindigkeit.
%
% Eingaben:
%   resultsTable - Tabelle mit Einzelmessungen (Volumen, Geschwindigkeit, Position)
%   statsTable   - Gruppierte Statistiktabelle mit Mittelwerten (optional)

    %% 1. Abbruchbedingung bei leeren Daten
    if isempty(resultsTable) || height(resultsTable) == 0
        warning('Keine Daten zur Visualisierung in resultsTable vorhanden.');
        return; 
    end

    %% 2. Hauptfigur: Physikalische Analyse (Volumen & Geschwindigkeit)
    figure('Name', 'Physikalische Analyse: Volumen & Geschwindigkeit', 'Position', [100, 100, 1200, 400]);

    % --- Subplot 1: Geschwindigkeit vs. Volumen (Korrelation) ---
    subplot(1, 2, 1);
    scatter(resultsTable.Volume_ul, resultsTable.Speed_m_s, 15, 'filled', ...
            'MarkerFaceColor', '#D95319', 'MarkerEdgeAlpha', 0.2, 'MarkerFaceAlpha', 0.2);

    % Lineare Regressionstruhe einzeichnen, falls genügend Daten vorhanden sind
    if height(resultsTable) >= 2
        p = polyfit(resultsTable.Volume_ul, resultsTable.Speed_m_s, 1);
        xFit = linspace(min(resultsTable.Volume_ul), max(resultsTable.Volume_ul), 100);
        hold on; 
        plot(xFit, polyval(p, xFit), 'k--', 'LineWidth', 1.5); 
        hold off;
    end

    xlabel('Lokales Blasenvolumen [\muL]'); 
    ylabel('Lokale Geschwindigkeit [m/s]');
    title('Geschwindigkeit vs. Echtes Volumen'); 
    grid on;

    % --- Subplot 2: Volumenabnahme ueber die Kanallaenge ---
    subplot(1, 2, 2);
    % Farbkodierung nach Geschwindigkeit
    scatter(resultsTable.Position_X_mm, resultsTable.Volume_ul, 15, resultsTable.Speed_m_s, ...
            'filled', 'MarkerEdgeAlpha', 0.4, 'MarkerFaceAlpha', 0.4);

    colormap('jet'); 
    cb = colorbar; 
    cb.Label.String = 'Geschwindigkeit [m/s]';
    xlabel('Kanalposition X [mm] (Distanz ab Einlass)');
    ylabel('Blasenvolumen [\muL]');
    title('Volumenabnahme ueber Kanallaenge'); 
    grid on;

    %% 3. Zusatzfigur: Validierung der Zweiphasen-Geschwindigkeit
    % Wird nur gezeichnet, wenn die Statistik-Tabelle existiert und die Spalte berechnet wurde
    if ~isempty(statsTable) && ismember('Expected_Speed_m_s', statsTable.Properties.VariableNames)
        figure('Name', 'Validierung der Zweiphasen-Geschwindigkeit', 'Position', [150, 150, 800, 500]);
        hold on;
        
        % 1. Fehlerbalken zuerst zeichnen (im Hintergrund, ohne Variable)
        errorbar(statsTable.BinCenter_mm, statsTable.mean_Speed_m_s, statsTable.std_Speed_m_s, ...
            'b', 'LineStyle', 'none', 'LineWidth', 1);
        
        % 2. Gemessene Geschwindigkeit (als p1 speichern)
        p1 = plot(statsTable.BinCenter_mm, statsTable.mean_Speed_m_s, '-o', ...
            'LineWidth', 2, 'MarkerSize', 8, 'MarkerFaceColor', 'b', 'Color', 'b');
        
        % 3. Erwartete Geschwindigkeit (als p2 speichern)
        p2 = plot(statsTable.BinCenter_mm, statsTable.Expected_Speed_m_s, '--s', ...
            'LineWidth', 2, 'MarkerSize', 8, 'MarkerFaceColor', 'r', 'Color', 'r');
        
        xlabel('Kanalposition X [mm] (Distanz ab Eintritt)');
        ylabel('Zweiphasen-Geschwindigkeit v_{tp} [m/s]');
        title('Vergleich: Gemessene vs. Erwartete Geschwindigkeitsabnahme');
        
        % ---> LEGENDE FIX: Zuweisung GANZ am Ende <---
        legend([p1, p2], {'Gemessen (Bildauswertung)', 'Erwartet (aus Volumenverlust berechnet)'}, 'Location', 'best');
        
        grid on; hold off;
    end

end
