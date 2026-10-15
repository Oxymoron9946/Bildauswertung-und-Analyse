function erzeuge_Dokubilder(batchCsv)
% ERZEUGE_DOKUBILDER Erzeugt alle Abbildungen des Handbuchs nach docs/bilder.
%
% Wertet ein Beispielvideo mit Live-Ansicht und Methodik-Abbildungen aus,
% zeichnet alle Plots und nimmt die Oberfläche in ihren Zuständen auf.
%
% Parameter
% ---------
% batchCsv : Batch-Ergebnisdatei für die Verlaufsplots und den GUI-Ergebnistab
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
    cfg.pfade.abbildungen = ziel;
    cfg.abbildungen.exportieren = true;
    cfg.abbildungen.dpi = 200;
    cfg.anzeige.live = true;
    video = fullfile(cfg.pfade.messdaten, 'PTFE_1000_600', 'Auswertung_20_CO2', 'Pos_1_Kal_1', ...
        '0.198_0.111_Pos_1_R_1000_PTFE_600', '200fps_001', 'XSM-3520 Camera 0330_.avi');
    stil = videoauswertung.plots.PlotStil(cfg);
    stil.Formate = {'png'};
    stil.Dpi = 150;

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
    stil.Sprache = 'en';
    speichere(stil, videoauswertung.plots.plot_Profil(bins, stil), fullfile(ziel, 'plot_profil_en'));

    %% Oberfläche
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
    exportapp(fig, fullfile(ziel, 'gui_ergebnisse_einzel.png'));
    tabs.SelectedTab = findall(tabs, 'Type', 'uitab', 'Title', 'Live-Ansicht');
    drawnow;
    exportapp(fig, fullfile(ziel, 'gui_live.png'));
    bg = findall(fig, 'Type', 'uibuttongroup');
    rb = findall(bg, 'Tag', 'batch');
    bg.SelectedObject = rb;
    bg.SelectionChangedFcn(bg, struct('NewValue', rb));
    drawnow;
    exportapp(fig, fullfile(ziel, 'gui_batch.png'));

    % Echter Batch-Lauf über einen kleinen Messordner, dann Ergebnistab
    pfad.Value = fullfile(gui.pfade.messdaten, 'PVC_1500_1150');
    start.ButtonPushedFcn(start, []);
    exportapp(fig, fullfile(ziel, 'gui_ergebnisse_batch.png'));
    delete(fig);
    fprintf('Abbildungen in %s\n', ziel);
end

function speichere(stil, fig, pfad)
    fig.Visible = 'off';
    stil.speichere(fig, pfad);
    close(fig);
end
