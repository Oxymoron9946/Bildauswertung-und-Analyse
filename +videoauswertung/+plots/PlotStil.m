classdef PlotStil
% PLOTSTIL Gemeinsamer Stil aller Ergebnisplots.
%
% Größe in cm, Sprache der Beschriftung (de/en), Ausgabeformate und
% Auflösung. Plots werden immer im hellen Theme erzeugt, unabhängig vom
% MATLAB-Desktop.
%
% Beispiel
% --------
%   stil = videoauswertung.plots.PlotStil(config());
%   stil.Sprache = 'en';
%   fig = videoauswertung.plots.plot_Profil(bins, stil);
%   stil.speichere(fig, fullfile('output', 'profil'));   % profil.png, profil.pdf

    properties
        Sprache  (1,:) char {mustBeMember(Sprache, {'de', 'en'})} = 'de'
        Breite_cm (1,1) double {mustBePositive} = 16
        Hoehe_cm  (1,1) double {mustBePositive} = 9
        Formate  cell = {'png', 'pdf'}
        Dpi      (1,1) double {mustBePositive} = 300
        Schriftgroesse (1,1) double {mustBePositive} = 10
    end

    methods
        function stil = PlotStil(cfg)
            % PLOTSTIL Stil aus cfg.plots (ohne Argument: Standardwerte).
            if nargin < 1
                return;
            end
            stil.Sprache   = cfg.plots.sprache;
            stil.Breite_cm = cfg.plots.breite_cm;
            stil.Hoehe_cm  = cfg.plots.hoehe_cm;
            stil.Formate   = cfg.plots.formate;
            stil.Dpi       = cfg.plots.dpi;
        end

        function fig = neue_Figur(stil, sichtbar)
            % NEUE_FIGUR Figur in der eingestellten Größe (cm), helles Theme.
            if nargin < 2
                sichtbar = 'on';
            end
            fig = figure('Units', 'centimeters', 'Position', [2 2 stil.Breite_cm stil.Hoehe_cm], ...
                'Visible', sichtbar, 'Color', 'w');
            theme(fig, 'light');
        end

        function formatiere(stil, ax)
            % FORMATIERE Schriftgröße, Gitter und Rahmen einer Achse.
            set(ax, 'FontSize', stil.Schriftgroesse, 'Box', 'on');
            grid(ax, 'on');
        end

        function s = text(stil, schluessel)
            % TEXT Beschriftung in der eingestellten Sprache.
            t = videoauswertung.plots.PlotStil.texte();
            if ~isfield(t, schluessel)
                error('videoauswertung:plotText', 'Unbekannter Beschriftungsschlüssel: %s', schluessel);
            end
            s = t.(schluessel).(stil.Sprache);
        end

        function dateien = speichere(stil, fig, pfadOhneEndung)
            % SPEICHERE Figur in allen Formaten aus stil.Formate speichern.
            ordner = fileparts(pfadOhneEndung);
            if ~isempty(ordner) && ~isfolder(ordner)
                mkdir(ordner);
            end
            dateien = cell(size(stil.Formate));
            for k = 1:numel(stil.Formate)
                dateien{k} = [pfadOhneEndung '.' stil.Formate{k}];
                if strcmpi(stil.Formate{k}, 'pdf')
                    exportgraphics(fig, dateien{k}, 'ContentType', 'vector');
                else
                    exportgraphics(fig, dateien{k}, 'Resolution', stil.Dpi);
                end
            end
        end
    end

    methods (Static)
        function t = texte()
            % Alle Achsen-, Legenden- und Titeltexte (de/en).
            t.position     = struct('de', 'Kanalposition x [mm]', 'en', 'Channel position x [mm]');
            t.v            = struct('de', 'Blasengeschwindigkeit u_B [m/s]', 'en', 'Bubble velocity u_B [m/s]');
            t.L_B          = struct('de', 'Blasenlänge L_B [mm]', 'en', 'Bubble length L_B [mm]');
            t.L_UC         = struct('de', 'Unit-Cell-Länge L_{UC} [mm]', 'en', 'Unit cell length L_{UC} [mm]');
            t.laenge       = struct('de', 'Länge [mm]', 'en', 'Length [mm]');
            t.anpassung    = struct('de', 'lineare Anpassung', 'en', 'linear fit');
            t.messpunkte   = struct('de', 'Messpunkte', 'en', 'measurements');
            t.kameraposition = struct('de', 'Kameraposition', 'en', 'Camera position');
            t.titel_v_LB   = struct('de', 'Geschwindigkeit über Blasenlänge', 'en', 'Velocity vs. bubble length');
            t.titel_LB_x   = struct('de', 'Blasenlänge entlang des Kanals', 'en', 'Bubble length along the channel');
            t.titel_profil = struct('de', 'Mittlere Blasen- und Unit-Cell-Länge', 'en', 'Mean bubble and unit cell length');
            t.titel_verlauf_v  = struct('de', 'Geschwindigkeitsverlauf', 'en', 'Velocity profile');
            t.titel_verlauf_LB = struct('de', 'Blasenlängenverlauf', 'en', 'Bubble length profile');
            t.gas          = struct('de', 'Gas', 'en', 'gas');
            t.fluessig     = struct('de', 'Flüssigkeit', 'en', 'liquid');
        end
    end
end
