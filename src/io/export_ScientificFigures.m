function export_ScientificFigures(I_roi, B_before, B_after, seeds, det, channelHeightEstimate, params, frameIdx, px2mm)
% EXPORT_SCIENTIFICFIGURES Speichert hochauflösende PNG-Bilder (600 DPI) 
% der einzelnen Bildverarbeitungsschritte für die wissenschaftliche Arbeit.

    % Prüfen, ob dieser Frame exportiert werden soll
    if ~isfield(params, 'exportFrame') || frameIdx ~= params.exportFrame
        return;
    end

    % Verzeichnis für den Export festlegen (LaTeX-Ordner)
    exportDir = '/home/sebastian/Sebastian/Studium/Forschungspraktikum/LaTex/Arbeit_Overleaf/images/Bildauswertung Original/';
    if ~exist(exportDir, 'dir')
        mkdir(exportDir);
    end
    
    fprintf('\n--- EXPORTIERE ABBILDUNGEN FÜR FRAME %d NACH %s ---\n', frameIdx, exportDir);
    
    % Erstelle einen unsichtbaren Export-Figure (um Flackern zu vermeiden)
    hExp = figure('Visible', 'off', 'Position', [100, 100, 1200, 400]);
    axExp = axes(hExp);
    
    % --- Abb 1: Originalbild ---
    imshow(I_roi, 'Parent', axExp);
    exportgraphics(hExp, fullfile(exportDir, 'Abb1_Original.png'), 'Resolution', 600);
    
    % --- Abb 2: Kontrastverbessert ---
    if isfield(seeds, 'I_eq')
        imshow(seeds.I_eq, 'Parent', axExp);
        exportgraphics(hExp, fullfile(exportDir, 'Abb2_Kontrast.png'), 'Resolution', 600);
    end
    
    % --- Abb 3: Rohes Binärbild ---
    imshow(B_before, 'Parent', axExp);
    exportgraphics(hExp, fullfile(exportDir, 'Abb3_Binaer_Roh.png'), 'Resolution', 600);
    
    % --- Abb 4: Gesäubertes Binärbild (B_clean) ---
    if isfield(seeds, 'B_clean')
        imshow(seeds.B_clean, 'Parent', axExp);
        exportgraphics(hExp, fullfile(exportDir, 'Abb4_Binaer_Clean.png'), 'Resolution', 600);
    end
    
    % --- Abb 5: Kanalgeometrie ---
    if isfield(seeds, 'B_clean')
        imshow(seeds.B_clean, 'Parent', axExp);
    else
        imshow(B_before, 'Parent', axExp);
    end
    hold(axExp, 'on');
    if isfield(seeds, 'mid_line_y')
        plot(axExp, 1:length(seeds.mid_line_y), seeds.mid_line_y, 'c-', 'LineWidth', 1.5);
    end
    % Wir zeichnen die Kanalwände rot ein (anhand der gefundenen Ränder)
    if isfield(seeds, 'y_top_line') && isfield(seeds, 'y_bot_line')
        plot(axExp, 1:length(seeds.y_top_line), seeds.y_top_line, 'r-', 'LineWidth', 1.5);
        plot(axExp, 1:length(seeds.y_bot_line), seeds.y_bot_line, 'r-', 'LineWidth', 1.5);
    end
    hold(axExp, 'off');
    exportgraphics(hExp, fullfile(exportDir, 'Abb5_Kanalgeometrie.png'), 'Resolution', 600);
    
    % --- Abb 6: Raycasting (Kantenklassifizierung) ---
    if isfield(seeds, 'B_clean')
        imshow(seeds.B_clean, 'Parent', axExp);
    else
        imshow(B_before, 'Parent', axExp);
    end
    hold(axExp, 'on');
    % Mittellinie wurde hier auf Wunsch entfernt
    if isfield(seeds, 'ray_x') && ~isempty(seeds.ray_x)
        % Nur jede 3. Linie zeichnen, um das Bild nicht zu überladen
        for i = 1:3:length(seeds.ray_x)
            plot(axExp, [seeds.ray_x(i), seeds.ray_x(i)], [seeds.ray_y0(i), seeds.ray_y1(i)], 'm-', 'LineWidth', 0.5);
        end
    end
    if isfield(seeds, 'slug_cx') && ~isempty(seeds.slug_cx)
        % slug_cx (rechte Kante der Blase) -> Grün (Steuerbord)
        plot(axExp, seeds.slug_cx, seeds.slug_cy, 'g.', 'MarkerSize', 1);
    end
    if isfield(seeds, 'bub_cx') && ~isempty(seeds.bub_cx)
        % bub_cx (linke Kante der Blase) -> Rot (Backbord)
        plot(axExp, seeds.bub_cx, seeds.bub_cy, 'r.', 'MarkerSize', 1);
    end
    if isfield(seeds, 'tie_cx') && ~isempty(seeds.tie_cx)
        plot(axExp, seeds.tie_cx, seeds.tie_cy, 'c.', 'MarkerSize', 1);
    end
    hold(axExp, 'off');
    exportgraphics(hExp, fullfile(exportDir, 'Abb6_Raycasting_Kanten.png'), 'Resolution', 600);
    
    % --- Abb 7: Region Growing Maske (mit Wänden und Seeds) ---
    if isfield(seeds, 'Mask') && isfield(seeds, 'Marker')
        % Zeige die Maske (weiß) auf schwarzem Grund
        imshow(seeds.Mask, 'Parent', axExp);
        hold(axExp, 'on');
        
        % Zeichne die ursprünglichen roten/grünen Kanten als orange Punkte
        if isfield(seeds, 'bub_cx') && ~isempty(seeds.bub_cx)
            plot(axExp, seeds.bub_cx, seeds.bub_cy, '.', 'Color', [1 0.5 0], 'MarkerSize', 1);
        end
        if isfield(seeds, 'slug_cx') && ~isempty(seeds.slug_cx)
            plot(axExp, seeds.slug_cx, seeds.slug_cy, '.', 'Color', [1 0.5 0], 'MarkerSize', 1);
        end
        
        % Zeichne die tatsächlichen Seed-Orte (Marker) in Blau ein
        [y_seed, x_seed] = find(seeds.Marker);
        if ~isempty(x_seed)
            plot(axExp, x_seed, y_seed, 'b.', 'MarkerSize', 1); % Blau
        end
        
        hold(axExp, 'off');
        exportgraphics(hExp, fullfile(exportDir, 'Abb7_RegionGrowing_Maske.png'), 'Resolution', 600);
    end
    
    % --- Abb 8: Finales gefülltes Bild ---
    imshow(B_after, 'Parent', axExp);
    exportgraphics(hExp, fullfile(exportDir, 'Abb8_Gefuellt.png'), 'Resolution', 600);
    
    % --- Abb 9: Finale Messung ---
    imshow(I_roi, 'Parent', axExp);
    hold(axExp, 'on');
    if isfield(params, 'dimOffsetY')
        dim_offset = params.dimOffsetY;
    else
        dim_offset = 45;
    end
    
    for j = 1:numel(det)
        % Linien 1 Pixel nach außen verschieben, damit sie im Slug liegen
        x_l = det(j).leftX - 1;
        x_r = det(j).rightX + 1;
        y_mid = det(j).leftY;
        dim_y = y_mid - dim_offset;
        
        % Linienstärke verringert (0.5 statt 1.5 für gestrichelt, 1.0 statt 2 für durchgezogen)
        plot(axExp, [x_l, x_l], [y_mid, dim_y], 'm:', 'LineWidth', 0.5);
        plot(axExp, [x_r, x_r], [y_mid, dim_y], 'm:', 'LineWidth', 0.5);
        plot(axExp, [x_l, x_r], [dim_y, dim_y], 'm-', 'LineWidth', 1.0);
        
        len_mm = (x_r - x_l) * px2mm;
        text(axExp, (x_l+x_r)/2, dim_y-15, sprintf('%.2f\nmm', len_mm), ...
            'Color','m','FontWeight','bold','HorizontalAlignment','center', 'FontSize', 10);
    end
    hold(axExp, 'off');
    exportgraphics(hExp, fullfile(exportDir, 'Abb9_FinaleMessung.png'), 'Resolution', 600);
    
    close(hExp);
    fprintf('Export abgeschlossen!\n\n');
end