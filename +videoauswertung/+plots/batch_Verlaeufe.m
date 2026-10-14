function batch_Verlaeufe(MasterTableResults, MasterTableStats, plotsDir)
% GENERATEBATCHPLOTS Erstellt automatische Visualisierungen gruppiert nach Gas/Liq und Setup

if ~isfolder(plotsDir)
    mkdir(plotsDir);
end
if isempty(MasterTableStats) || height(MasterTableStats) == 0
    warning('Keine Statistikdaten für den Plot vorhanden.');
    return;
end
fprintf('Erstelle Plots in %s ...\n', plotsDir);

%% Gruppierung nach Einstellungen UND Setup-Parametern
if ismember('GasVelocity', MasterTableStats.Properties.VariableNames)
    
    % HIER NEU: Wir gruppieren jetzt auch nach Material, Geometrie und Kanalgröße!
    combos = unique(MasterTableStats(:, {'GasVelocity', 'LiquidVelocity', 'Material', 'Geometrie', 'Kanal_um'}));
    
    for i = 1:height(combos)
        gStr   = combos.GasVelocity(i);
        lStr   = combos.LiquidVelocity(i);
        matStr = combos.Material(i);
        geoStr = combos.Geometrie(i);
        kanNum = combos.Kanal_um(i);
        
        if ismissing(gStr) || gStr == "NaN"
            continue;
        end
        
        % HIER NEU: Filter für die exakte Kombination anwenden
        idx_conf = (MasterTableStats.GasVelocity == gStr) & ...
                   (MasterTableStats.LiquidVelocity == lStr) & ...
                   (MasterTableStats.Material == matStr) & ...
                   (MasterTableStats.Geometrie == geoStr) & ...
                   (MasterTableStats.Kanal_um == kanNum);
               
        subStats = MasterTableStats(idx_conf, :);
        if isempty(subStats), continue; end
        
        positions = unique(subStats.CameraPosition(~isnan(subStats.CameraPosition)));
        colors = lines(max(3, length(positions))); 
        
        % Ein dynamischer Suffix für Dateiname und Titel
        setupSuffix = sprintf('%s_%s_%dum', matStr, geoStr, kanNum);
        
        %% PLOT 1: Geschwindigkeit
        figName_V = sprintf('Gas_%s_Liq_%s_%s_Geschwindigkeit', gStr, lStr, setupSuffix);
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
        title(sprintf('Geschwindigkeitsverlauf (Gas: %s, Liq: %s, %s)', gStr, lStr, setupSuffix), 'Interpreter', 'none');
        legend('Location', 'best');
        saveas(figV, fullfile(plotsDir, sprintf('%s.png', figName_V)));
        close(figV);
        
        %% PLOT 2: Blasenlaenge 
        figName_Len = sprintf('Gas_%s_Liq_%s_%s_Blasenlaenge', gStr, lStr, setupSuffix);
        figLen = figure('Name', figName_Len, 'Position', [150, 150, 900, 500], 'Visible', 'off');
        hold on; grid on; box on;
        
        for p = 1:length(positions)
            pos = positions(p);
            idx_pos = subStats.CameraPosition == pos;
            
            x = subStats.BinCenter_mm(idx_pos);
            y = subStats.mean_BubbleLength_mm(idx_pos);  
            y_err = subStats.std_BubbleLength_mm(idx_pos); 
            
            [x_sorted, sort_idx] = sort(x);
            errorbar(x_sorted, y(sort_idx), y_err(sort_idx), 's-', ...
                'Color', colors(p,:), 'MarkerFaceColor', colors(p,:), 'LineWidth', 1.5, ...
                'DisplayName', sprintf('Position %d', pos));
        end
        
        xlabel('Kanalposition X [mm]');
        ylabel('Blasenlaenge [mm]');
        title(sprintf('Blasenlaengenabnahme (Gas: %s, Liq: %s, %s)', gStr, lStr, setupSuffix), 'Interpreter', 'none');
        legend('Location', 'best');
        saveas(figLen, fullfile(plotsDir, sprintf('%s.png', figName_Len)));
        close(figLen);
    end
else
    warning('GasVelocity / LiquidVelocity Spalten fehlen.');
end
fprintf('Plots erfolgreich generiert.\n');
end