function erzeuge_Dokubilder(batchCsv)
% ERZEUGE_DOKUBILDER Erzeugt alle Abbildungen des Handbuchs nach docs/bilder.
%
% Wertet ein Beispielvideo mit Live-Ansicht und Kalibrierkontrolle aus,
% zeichnet die Ergebnisplots, nimmt die Oberfläche auf und zeichnet die
% Schaubilder zur Ordnerstruktur und zum Ordnernamen (Kapitel 2).
%
% Parameter
% ---------
% batchCsv : Batch-Ergebnisdatei für die Verlaufsplots (PTFE_1000_600)
%
% Aufruf (aus dem Projektordner, Messvideos nötig):
%   matlab -batch "addpath tools; erzeuge_Dokubilder('output/Output_MassTransfer/Auswertung_Masse_PTFE_R_1000um_72cm_20molCO2_600um.csv')"

    projekt = fileparts(fileparts(mfilename('fullpath')));
    addpath(projekt);
    ziel = fullfile(projekt, 'docs', 'bilder');
    if ~isfolder(ziel), mkdir(ziel); end
    tmp = tempname;
    mkdir(tmp);
    aufraeumen = onCleanup(@() rmdir(tmp, 's'));

    cfg = config();
    cfg.pfade.ausgabe = tmp;
    cfg.anzeige.live = true;
    video = fullfile(cfg.pfade.messdaten, 'PVC_1500_1150', 'Druck', 'Pos_1_Kal_3', ...
        '0.198_0.111_Pos_1_R_1500_PVC_1150_Druck', '200fps_001', 'XSM-3520 Camera 0330_.avi');
    stil = videoauswertung.plots.PlotStil(cfg);
    stil.Formate = {'png'};
    stil.Dpi = 150;

    %% Schaubilder Kapitel 2
    zeichne_Ordnerstruktur(fullfile(ziel, 'ordnerstruktur.png'));
    zeichne_Ordnername(fullfile(ziel, 'dateiname.png'));

    %% Einzelauswertung mit Live-Ansicht und Kalibrierkontrolle
    live = figure('Position', [100 100 1400 380], 'Color', 'w', 'Visible', 'off');
    theme(live, 'light');
    liveAx = axes(live);
    kalib = figure('Position', [100 100 1400 500], 'Color', 'w', 'Visible', 'off');
    theme(kalib, 'light');
    kalibAx = axes(kalib);
    rueck.live = @(I, seeds, det, px2mm, frame) videoauswertung.plots.zeige_Live(liveAx, I, seeds, det, px2mm, frame);
    rueck.kalibrierung = @(frame, info, px2mm, ok) videoauswertung.plots.zeige_Kalibrierung(kalibAx, frame, info, px2mm, ok);
    [~, rohdaten, bins] = videoauswertung.kern.auswerten_Einzel(cfg, video, [], rueck);
    exportgraphics(live, fullfile(ziel, 'plot_live.png'), 'Resolution', 150);
    exportgraphics(kalib, fullfile(ziel, 'plot_kalibrierung.png'), 'Resolution', 150);
    close([live kalib]);

    %% Ergebnisplots
    speichere(stil, videoauswertung.plots.plot_Laenge_Position(rohdaten, stil), fullfile(ziel, 'plot_laenge_position'));
    speichere(stil, videoauswertung.plots.plot_Profil(bins, stil), fullfile(ziel, 'plot_profil'));
    speichere(stil, videoauswertung.plots.plot_Geschwindigkeit_Laenge(rohdaten, stil), fullfile(ziel, 'plot_v_laenge'));
    tab = videoauswertung.plots.lies_Batchergebnis(batchCsv);
    sel = tab.GasVelocity == "0.07" & tab.LiquidVelocity == "0.111";
    speichere(stil, videoauswertung.plots.plot_Verlauf(tab(sel, :), 'Speed_m_s', stil), fullfile(ziel, 'plot_verlauf_v'));
    speichere(stil, videoauswertung.plots.plot_Verlauf(tab(sel, :), 'BubbleLength_mm', stil), fullfile(ziel, 'plot_verlauf_lb'));

    %% Oberfläche: Einzelmodus, Live-Ansicht nach einem Lauf, Batchmodus
    gui = config();
    gui.pfade.ausgabe = tmp;
    fig = videoauswertung.gui.VideoAnalysisApp(gui);
    drawnow;
    exportapp(fig, fullfile(ziel, 'gui_einzel.png'));
    pfad = findall(fig, 'Type', 'uieditfield');
    pfad.Value = video;
    start = findall(fig, 'Type', 'uibutton', 'Text', 'Start');
    start.ButtonPushedFcn(start, []);
    tabs = findall(fig, 'Type', 'uitabgroup');
    tabs.SelectedTab = findall(tabs, 'Type', 'uitab', 'Title', 'Live-Ansicht');
    drawnow;
    exportapp(fig, fullfile(ziel, 'gui_live.png'));
    delete(fig);

    fig = videoauswertung.gui.VideoAnalysisApp(gui);
    bg = findall(fig, 'Type', 'uibuttongroup');
    rb = findall(bg, 'Tag', 'batch');
    bg.SelectedObject = rb;
    bg.SelectionChangedFcn(bg, struct('NewValue', rb));
    pfad = findall(fig, 'Type', 'uieditfield');
    pfad.Value = fullfile(gui.pfade.messdaten, 'PTFE_1000_600');
    drawnow;
    pause(2);   % uiaxes einer frisch erzeugten App werden verzögert gezeichnet
    exportapp(fig, fullfile(ziel, 'gui_batch.png'));
    delete(fig);
    fprintf('Abbildungen in %s\n', ziel);
end

function speichere(stil, fig, pfad)
    fig.Visible = 'off';
    stil.speichere(fig, pfad);
    close(fig);
end

function zeichne_Ordnerstruktur(datei)
    % Ordnerbaum mit farbig markierten Ebenen und Erklärung je Zeile
    farben = struct('mess', [0.45 0.50 0.55], 'zwischen', [0.65 0.68 0.70], 'gruppe', [0.10 0.40 0.75], ...
        'kalib', [0.85 0.45 0.05], 'lauf', [0.15 0.55 0.25], 'aufnahme', [0.50 0.25 0.65], 'datei', [0.20 0.20 0.20]);
    z = { ...
        0, 'PTFE_1000_600',                    'mess',     'Messordner (Name frei wählbar)'; ...
        1, 'Auswertung_20_CO2',                'zwischen', 'beliebige Zwischenebenen (optional)'; ...
        2, 'Pos_1_Kal_1',                      'gruppe',   'Kalibriergruppe: Kameraposition 1, Kalibrierung 1'; ...
        3, 'Kalibrierung_1_Pos_1_08.04.2026',  'kalib',    'Kalibrierordner, genau einer je Gruppe'; ...
        4, 'XSM-3520 Camera 0330_.avi',        'datei',    'Kalibriervideo mit Lineal'; ...
        3, '0.198_0.111_Pos_1_R_1000_PTFE_600', 'lauf',    'Messlauf = Schlüssel ins Laborbuch (Aufbau: nächste Abbildung)'; ...
        4, '200fps_001',                       'aufnahme', 'Aufnahme: Bildrate 200 1/s, Nummer 001'; ...
        5, 'XSM-3520 Camera 0330_.avi',        'datei',    'Messvideo'; ...
        4, '200fps_002',                       'aufnahme', 'weitere Aufnahme desselben Messlaufs'; ...
        5, 'XSM-3520 Camera 0330_.avi',        'datei',    'Messvideo'; ...
        2, 'Pos_2_Kal_1',                      'gruppe',   'nächste Kameraposition …'};
    n = size(z, 1);
    fig = figure('Visible', 'off', 'Color', 'w', 'Units', 'pixels', 'Position', [0 0 1500 100 + 46*n]);
    theme(fig, 'light');
    ax = axes(fig, 'Position', [0 0 1 1], 'XLim', [0 1500], 'YLim', [0 100 + 46*n], 'YDir', 'reverse', 'Visible', 'off');
    hold(ax, 'on');
    einzug = 34; x0 = 30; y = @(k) 60 + 46*(k-1);
    for k = 1:n
        ebene = z{k, 1}; x = x0 + einzug*ebene;
        f = farben.(z{k, 3});
        if ebene > 0
            % Verbindung zum übergeordneten Ordner
            eltern = find([z{1:k-1, 1}] == ebene - 1, 1, 'last');
            xv = x0 + einzug*(ebene-1) + 10;
            plot(ax, [xv xv], [y(eltern) + 14, y(k)], '-', 'Color', [0.7 0.7 0.7], 'LineWidth', 1.2);
            plot(ax, [xv x - 6], [y(k) y(k)], '-', 'Color', [0.7 0.7 0.7], 'LineWidth', 1.2);
        end
        istDatei = strcmp(z{k, 3}, 'datei');
        if istDatei
            symbol = char(9633);  % Datei
        else
            symbol = char(9632);  % Ordner
        end
        text(ax, x, y(k), [symbol ' '], 'Color', f, 'FontSize', 15, 'VerticalAlignment', 'middle');
        t = text(ax, x + 20, y(k), z{k, 2}, 'Interpreter', 'none', 'FontName', 'Consolas', 'FontSize', 15, ...
            'FontWeight', ifelse(istDatei, 'normal', 'bold'), 'Color', f, 'VerticalAlignment', 'middle');
        e = t.Extent;
        plot(ax, [e(1) + e(3) + 12, 820], [y(k) y(k)], ':', 'Color', [0.82 0.82 0.82]);
        text(ax, 830, y(k), z{k, 4}, 'FontSize', 14, 'Color', [0.25 0.25 0.25], 'VerticalAlignment', 'middle');
    end
    exportgraphics(fig, datei, 'Resolution', 150, 'Padding', 20);   % Rand, sonst werden Glyphen oben beschnitten
    close(fig);
end

function zeichne_Ordnername(datei)
    % Messlauf-Name in seine Teile zerlegt, darunter Bedeutung und Einheit
    teile = { ...
        '0.198', 'j_G',      'Leerrohrgeschw. Gas',        'm/s'; ...
        '0.111', 'j_L',      'Leerrohrgeschw. Flüssigkeit', 'm/s'; ...
        'Pos_1', 'Position', 'Kameraposition',             '–'; ...
        'R',     'Form',     'R rund, Q quadratisch',      '–'; ...
        '1000',  'Kanal',    'Durchmesser/Kantenlänge',    'µm'; ...
        'PTFE',  'Material', 'Kanalmaterial',              '–'; ...
        '600',   'Nadel',    'Innendurchmesser Gasnadel',  'µm'; ...
        'Druck', 'Messart',  'optional: Druckkalibrierung', '–'};
    farben = [lines(7); 0.45 0.45 0.45];   % 8 Teile, eigene Farbe für den optionalen Zusatz
    fig = figure('Visible', 'off', 'Color', 'w', 'Units', 'pixels', 'Position', [0 0 1900 380]);
    theme(fig, 'light');
    ax = axes(fig, 'Position', [0 0 1 1], 'XLim', [0 1900], 'YLim', [0 380], 'YDir', 'reverse', 'Visible', 'off');
    hold(ax, 'on');
    x = 230; spalte = 230;
    for k = 1:size(teile, 1)
        if k > 1
            sep = text(ax, x, 80, '_', 'FontName', 'Consolas', 'FontSize', 30, 'Color', [0.55 0.55 0.55], ...
                'VerticalAlignment', 'middle', 'Interpreter', 'none');
            x = x + sep.Extent(3);
        end
        t = text(ax, x, 80, teile{k, 1}, 'FontName', 'Consolas', 'FontSize', 30, 'FontWeight', 'bold', ...
            'Color', farben(k, :), 'VerticalAlignment', 'middle', 'Interpreter', 'none');
        if k == size(teile, 1)
            t.FontAngle = 'italic';
        end
        e = t.Extent;
        mitte = e(1) + e(3)/2;
        unten = 118;
        ziel_x = 30 + spalte*(k-1) + spalte/2;
        plot(ax, [e(1) e(1) + e(3)], [unten unten], '-', 'Color', farben(k, :), 'LineWidth', 3);
        plot(ax, [mitte ziel_x], [unten 175], '-', 'Color', farben(k, :), 'LineWidth', 1.2);
        text(ax, ziel_x, 200, teile{k, 2}, 'FontSize', 15, 'FontWeight', 'bold', 'Color', farben(k, :), ...
            'HorizontalAlignment', 'center', 'Interpreter', 'none');
        text(ax, ziel_x, 240, teile{k, 3}, 'FontSize', 11.5, 'Color', [0.25 0.25 0.25], ...
            'HorizontalAlignment', 'center', 'Interpreter', 'none');
        text(ax, ziel_x, 275, ['[' teile{k, 4} ']'], 'FontSize', 12, 'Color', [0.35 0.35 0.35], ...
            'HorizontalAlignment', 'center', 'Interpreter', 'none');
        x = x + e(3);
    end
    text(ax, 30, 335, 'Dezimaltrennzeichen Punkt, Teile durch Unterstrich getrennt; „_Druck“ nur bei Druckkalibrierungen.', ...
        'FontSize', 12, 'Color', [0.35 0.35 0.35], 'Interpreter', 'none');
    exportgraphics(fig, datei, 'Resolution', 150, 'Padding', 20);   % Rand, sonst werden Glyphen oben beschnitten
    close(fig);
end

function w = ifelse(b, a, c)
    if b, w = a; else, w = c; end
end
