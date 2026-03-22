function generate_Batch_Plots(MasterTableResults, MasterTableStats, plotsDir)
% GENERATEBATCHPLOTS Erstellt automatische Visualisierungen gruppiert nach Gas/Liq-Einstellungen

if ~isfolder(plotsDir)
    mkdir(plotsDir);
end

if isempty(MasterTableStats) || height(MasterTableStats) == 0
    warning('Keine Statistikdaten für den Plot vorhanden.');
    return;
end

fprintf('Erstelle Plots (gruppiert nach Gas/Liq) in %s ...\n', plotsDir);

%% Gruppierung nach Einstellungen
if ismember('GasVelocity', MasterTableStats.Properties.VariableNames)
    combos = unique(MasterTableStats(:, {'GasVelocity', 'LiquidVelocity'}));
    
    for i = 1:height(combos)
        gStr = combos.GasVelocity(i);
        lStr = combos.LiquidVelocity(i);
        
        if ismissing(gStr) || gStr == "NaN"
            continue;
        end
        
        idx_conf = (MasterTableStats.GasVelocity == gStr) & (MasterTableStats.LiquidVelocity == lStr);
        subStats = MasterTableStats(idx_conf, :);
        
        if isempty(subStats), continue; end
        
        positions = unique(subStats.CameraPosition(~isnan(subStats.CameraPosition)));
        colors = lines(max(3, length(positions))); 
        
        %% PLOT 1: Geschwindigkeit
        figName_V = sprintf('Gas_%s_Liq_%s_Geschwindigkeit', gStr, lStr);
        figV = figure('Name', figName_V, 'Position', [100, 100, 900, 500], 'Visible', 'off');
        hold on; grid on; box on;
        
        for p = 1:length(positions)
            pos = positions(p);
            idx_pos = subStats.CameraPosition == pos;
            
            x = subStats.BinCenter_mm(idx_pos);
            y = subStats.mean_Speed_m_s(idx_pos);
            y_err = subStats.std_Speed_m_s(idx_pos);
            
            [x_sorted, sort_idx] = sort(x);
            errorbar(x_sorted, y(sort_idx), y_err(sort_idx), 'o-', ...
                'Color', colors(p,:), 'MarkerFaceColor', colors(p,:), 'LineWidth', 1.5, ...
                'DisplayName', sprintf('Position %d', pos));
        end
        
        xlabel('Kanalposition X [mm]');
        ylabel('Geschwindigkeit [m/s]');
        title(sprintf('Geschwindigkeitsverlauf (Gas: %s, Liq: %s)', gStr, lStr));
        legend('Location', 'best');
        saveas(figV, fullfile(plotsDir, sprintf('%s.png', figName_V)));
        close(figV);
        
        %% PLOT 2: Blasenlaenge (ersetzt Volumen!)
        figName_Len = sprintf('Gas_%s_Liq_%s_Blasenlaenge', gStr, lStr);
        figLen = figure('Name', figName_Len, 'Position', [150, 150, 900, 500], 'Visible', 'off');
        hold on; grid on; box on;
        
        for p = 1:length(positions)
            pos = positions(p);
            idx_pos = subStats.CameraPosition == pos;
            
            x = subStats.BinCenter_mm(idx_pos);
            y = subStats.mean_BubbleLength_mm(idx_pos);  % GEAENDERT!
            y_err = subStats.std_BubbleLength_mm(idx_pos); % GEAENDERT!
            
            [x_sorted, sort_idx] = sort(x);
            errorbar(x_sorted, y(sort_idx), y_err(sort_idx), 's-', ...
                'Color', colors(p,:), 'MarkerFaceColor', colors(p,:), 'LineWidth', 1.5, ...
                'DisplayName', sprintf('Position %d', pos));
        end
        
        xlabel('Kanalposition X [mm]');
        ylabel('Blasenlaenge [mm]');
        title(sprintf('Blasenlaengenabnahme (Gas: %s, Liq: %s)', gStr, lStr));
        legend('Location', 'best');
        saveas(figLen, fullfile(plotsDir, sprintf('%s.png', figName_Len)));
        close(figLen);
    end
else
    warning('GasVelocity / LiquidVelocity Spalten fehlen.');
end
fprintf('Plots erfolgreich generiert.\n');
end
