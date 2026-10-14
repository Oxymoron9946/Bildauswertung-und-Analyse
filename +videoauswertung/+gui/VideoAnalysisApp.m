function fig = VideoAnalysisApp(cfg)
% VIDEOANALYSISAPP Bedienoberfläche der Videoauswertung.
%
% Die GUI ruft nur Funktionen aus videoauswertung.kern auf. Startwerte
% stammen aus config(); was hier eingestellt wird, überschreibt nur die
% Kopie für den jeweiligen Lauf.
%
% Parameter
% ---------
% cfg : optional, struct aus config() (Standard: config())
%
% Rückgabe
% --------
% fig : uifigure der App

    if nargin < 1
        cfg = config();
    end
    fig = uifigure('Name', 'Videoauswertung', 'Position', [100 50 1000 800]);
    fig.UserData.CancelRequested = false;

    %% Bedienfeld
    panel = uipanel(fig, 'Position', [10 540 980 250], 'Title', 'Steuerung', 'FontWeight', 'bold');

    bg = uibuttongroup(panel, 'Position', [10 160 300 60], 'Title', 'Modus', 'SelectionChangedFcn', @modusGewechselt);
    uiradiobutton(bg, 'Position', [10 15 120 22], 'Text', 'Einzelvideo', 'Tag', 'single');
    uiradiobutton(bg, 'Position', [150 15 150 22], 'Text', 'Batch (Ordner)', 'Tag', 'batch');

    uilabel(panel, 'Position', [10 130 100 22], 'Text', 'Pfad:');
    pfadFeld = uieditfield(panel, 'text', 'Position', [10 105 200 22]);
    uibutton(panel, 'Position', [220 105 90 22], 'Text', 'Auswählen…', 'ButtonPushedFcn', @auswaehlen);

    uilabel(panel, 'Position', [340 200 100 22], 'Text', 'Sens. Start:');
    sensStart = uieditfield(panel, 'numeric', 'Position', [420 200 80 22], 'Value', cfg.gui.sens_start);
    uilabel(panel, 'Position', [340 160 100 22], 'Text', 'Sens. Ende:');
    sensEnde = uieditfield(panel, 'numeric', 'Position', [420 160 80 22], 'Value', cfg.gui.sens_ende, 'Enable', 'off');

    uilabel(panel, 'Position', [340 80 150 22], 'Text', 'Jedes N-te Frame zeigen:');
    nFeld = uieditfield(panel, 'numeric', 'Position', [500 80 60 22], 'Value', cfg.anzeige.jedes_n_frame);

    liveBox = uicheckbox(panel, 'Position', [540 200 200 22], 'Text', 'Live-Ansicht', 'Value', 1);
    kalibBox = uicheckbox(panel, 'Position', [540 160 200 22], 'Text', 'Kalibrierung zeigen', 'Value', 0);

    startKnopf = uibutton(panel, 'Position', [780 140 90 40], 'Text', 'Start', 'FontSize', 14, ...
        'FontWeight', 'bold', 'BackgroundColor', [0.2 0.6 0.2], 'FontColor', 'w', 'ButtonPushedFcn', @start);
    stopKnopf = uibutton(panel, 'Position', [875 140 90 40], 'Text', 'Stop', 'FontSize', 14, ...
        'FontWeight', 'bold', 'BackgroundColor', [0.8 0.2 0.2], 'FontColor', 'w', 'ButtonPushedFcn', @stop, ...
        'Enable', 'off');
    status = uilabel(panel, 'Position', [780 100 180 22], 'Text', 'Bereit.', 'HorizontalAlignment', 'center');

    %% Anzeige
    tabs = uitabgroup(fig, 'Position', [10 10 980 520]);
    tabLive = uitab(tabs, 'Title', 'Live-Ansicht');
    achse = uiaxes(tabLive, 'Position', [10 10 960 470]);
    title(achse, 'Warte auf Video …');
    tabKalib = uitab(tabs, 'Title', 'Kalibrierung');
    kalibAchse = uiaxes(tabKalib, 'Position', [10 10 960 470]);
    tabErgebnis = uitab(tabs, 'Title', 'Ergebnisse');
    uilabel(tabErgebnis, 'Position', [10 455 90 22], 'Text', 'Darstellung:');
    auswahl = uidropdown(tabErgebnis, 'Position', [100 455 600 22], 'Items', {'(noch keine Ergebnisse)'}, ...
        'ValueChangedFcn', @(~, ~) zeichneErgebnis());
    ergebnisAchse = uiaxes(tabErgebnis, 'Position', [10 10 960 435]);
    stil = videoauswertung.plots.PlotStil(cfg);
    letztes = struct('art', '', 'rohdaten', [], 'bins', [], 'batch', table(), ...
        'eintraege', struct('plot', {}, 'sel', {}));

    %% Callbacks
    function modusGewechselt(~, event)
        batch = strcmp(event.NewValue.Tag, 'batch');
        liveBox.Enable = ~batch; liveBox.Value = ~batch;
        kalibBox.Enable = ~batch;
        if batch, kalibBox.Value = 0; end
        nFeld.Enable = ~batch;
        sensEnde.Enable = batch;
        pfadFeld.Value = '';
    end

    function auswaehlen(~, ~)
        if strcmp(bg.SelectedObject.Tag, 'single')
            [datei, ordner] = uigetfile('*.avi', 'Messvideo auswählen', cfg.pfade.messdaten);
            if ~isequal(datei, 0), pfadFeld.Value = fullfile(ordner, datei); end
        else
            ordner = uigetdir(cfg.pfade.messdaten, 'Messordner auswählen');
            if ~isequal(ordner, 0), pfadFeld.Value = ordner; end
        end
    end

    function stop(~, ~)
        fig.UserData.CancelRequested = true;
        stopKnopf.Enable = 'off';
        status.Text = 'Breche ab …';
        drawnow;
        if strcmp(bg.SelectedObject.Tag, 'batch')
            % Laufende Worker hart beenden; der Batch meldet den Abbruch
            pool = gcp('nocreate');
            if ~isempty(pool), delete(pool); end
        end
    end

    function start(~, ~)
        ziel = pfadFeld.Value;
        if isempty(ziel)
            uialert(fig, 'Bitte zuerst eine Datei oder einen Ordner auswählen.', 'Fehlende Eingabe');
            return;
        end
        lauf = cfg;
        lauf.anzeige.live = liveBox.Value;
        lauf.anzeige.kalibrierung = kalibBox.Value;
        lauf.anzeige.jedes_n_frame = nFeld.Value;

        rueck.abbruch = @() fig.UserData.CancelRequested;
        rueck.live = @(I, seeds, det, px2mm, frame) videoauswertung.plots.zeige_Live(achse, I, seeds, det, px2mm, frame);
        if lauf.anzeige.kalibrierung
            rueck.kalibrierung = @(frame, info, px2mm, ok) zeigeKalibrierung(frame, info, px2mm, ok);
        end

        fig.UserData.CancelRequested = false;
        startKnopf.Enable = 'off';
        stopKnopf.Enable = 'on';
        status.Text = 'Auswertung läuft …';
        tabs.SelectedTab = tabLive;
        drawnow;
        try
            if strcmp(bg.SelectedObject.Tag, 'single')
                [~, rohdaten, bins] = videoauswertung.kern.auswerten_Einzel(lauf, ziel, sensStart.Value, rueck);
                if ~isempty(rohdaten)
                    videoauswertung.plots.plot_Laenge_Position(rohdaten, stil, achse);
                    zeigeErgebnisse('einzel', rohdaten, bins, {});
                end
            else
                rueck.fortschritt = fortschrittsbalken(achse);
                dateien = videoauswertung.kern.auswerten_Batch(lauf, ziel, rueck);
                cla(achse); axis(achse, 'on');
                zeigeErgebnisse('batch', [], [], dateien);
            end
            status.Text = 'Fertig.';
        catch ME
            status.Text = 'Fehler!';
            uialert(fig, ME.message, 'Fehler bei der Auswertung');
        end
        startKnopf.Enable = 'on';
        stopKnopf.Enable = 'off';
    end

    function zeigeKalibrierung(frame, info, px2mm, ok)
        videoauswertung.plots.zeige_Kalibrierung(kalibAchse, frame, info, px2mm, ok);
    end

    function zeigeErgebnisse(art, rohdaten, bins, dateien)
        % Auswahlliste der Ergebnisplots füllen und den ersten zeichnen
        letztes.art = art;
        letztes.rohdaten = rohdaten;
        letztes.bins = bins;
        % Jeder Eintrag merkt sich Plotart und (im Batch) die Zeilenauswahl
        if strcmp(art, 'einzel')
            texte = {stil.text('titel_LB_x'), stil.text('titel_profil'), stil.text('titel_v_LB')};
            letztes.eintraege = struct('plot', {'LB_x', 'profil', 'v_LB'}, 'sel', []);
        else
            letztes.batch = videoauswertung.plots.lies_Batchergebnis(dateien);
            [texte, letztes.eintraege] = batch_Eintraege(letztes.batch, stil);
        end
        if isempty(texte)
            auswahl.Items = {'(keine Ergebnisse)'};
            auswahl.ItemsData = 0;
            return;
        end
        auswahl.Items = texte;
        auswahl.ItemsData = 1:numel(texte);
        auswahl.Value = 1;
        zeichneErgebnis();
        tabs.SelectedTab = tabErgebnis;
    end

    function zeichneErgebnis()
        k = auswahl.Value;
        if isempty(k) || k == 0
            return;
        end
        e = letztes.eintraege(k);
        switch e.plot
            case 'LB_x'
                videoauswertung.plots.plot_Laenge_Position(letztes.rohdaten, stil, ergebnisAchse);
            case 'profil'
                videoauswertung.plots.plot_Profil(letztes.bins, stil, ergebnisAchse);
            case 'v_LB'
                videoauswertung.plots.plot_Geschwindigkeit_Laenge(letztes.rohdaten, stil, ergebnisAchse);
            otherwise
                videoauswertung.plots.plot_Verlauf(letztes.batch(e.sel, :), e.plot, stil, ergebnisAchse);
        end
    end
end

function [texte, eintraege] = batch_Eintraege(tab, stil)
    % Je Einstellung (Messart, Material, Form, Kanal, Gas, Flüssigkeit) zwei
    % Einträge: Geschwindigkeits- und Blasenlängenverlauf
    texte = {};
    eintraege = struct('plot', {}, 'sel', {});
    spalten = {'Messart', 'Material', 'Geometrie', 'Kanal_um', 'GasVelocity', 'LiquidVelocity'};
    kombis = unique(tab(:, spalten), 'rows');
    for i = 1:height(kombis)
        k = kombis(i, :);
        sel = tab.Messart == k.Messart & tab.Material == k.Material & tab.Geometrie == k.Geometrie & ...
              tab.Kanal_um == k.Kanal_um & tab.GasVelocity == k.GasVelocity & tab.LiquidVelocity == k.LiquidVelocity;
        for g = {'Speed_m_s', 'titel_verlauf_v'; 'BubbleLength_mm', 'titel_verlauf_LB'}'
            texte{end+1} = sprintf('%s – %s %s %s %d µm – %s %s m/s, %s %s m/s', stil.text(g{2}), ... %#ok<AGROW>
                k.Messart, k.Material, k.Geometrie, k.Kanal_um, stil.text('gas'), k.GasVelocity, ...
                stil.text('fluessig'), k.LiquidVelocity);
            eintraege(end+1) = struct('plot', g{1}, 'sel', sel); %#ok<AGROW>
        end
    end
end

function f = fortschrittsbalken(ax)
    cla(ax);
    title(ax, '');
    axis(ax, 'off');
    xlim(ax, [0, 100]);
    ylim(ax, [0, 10]);
    rectangle(ax, 'Position', [10, 4, 80, 2], 'EdgeColor', 'k', 'LineWidth', 1);
    balken = rectangle(ax, 'Position', [10, 4, 0, 2], 'FaceColor', [0.2 0.6 0.2], 'EdgeColor', 'none');
    text_h = text(ax, 50, 7, 'Batch: 0 %', 'HorizontalAlignment', 'center', 'FontSize', 14, 'FontWeight', 'bold');
    f = @aktualisiere;
    function aktualisiere(fertig, gesamt)
        anteil = fertig / gesamt;
        balken.Position(3) = anteil * 80;
        text_h.String = sprintf('Batch: %.1f %% (%d / %d Videos)', anteil * 100, fertig, gesamt);
        drawnow;
    end
end
