function cfg = config()
% CONFIG Einzige Einstellungsdatei der Videoauswertung.
%
% Alle Pfade, Auswerteparameter, Plot- und GUI-Einstellungen stehen hier.
% Skripte, GUI und Tests lesen ausschließlich diese Datei. Eine geänderte
% Kopie eines Laufs lässt sich als JSON speichern und wieder laden
% (siehe videoauswertung.io.schreibe_Laufconfig / lade_Laufconfig).
%
% Aufruf
% ------
%   cfg = config();
%   cfg.detektion.sens = 0.9;            % Werte vor dem Lauf anpassen
%   videoauswertung.kern.auswerten(cfg, 'PTFE_1000_600');
%
% Einheiten stehen im Namen (_mm, _px, _m_s) oder im Kommentar.
% Bedeutung, Herkunft und Sensitivität jedes Eintrags: docs/03_konfiguration.md

    wurzel = fileparts(mfilename('fullpath'));

    %% Pfade
    % Alle relativen Angaben beziehen sich auf den Projektordner, nie auf pwd.
    cfg.pfade.projekt    = wurzel;
    cfg.pfade.messdaten  = wurzel;                                 % Ordner, unter dem die Messreihen liegen
    cfg.pfade.laborbuch  = fullfile(wurzel, 'data', 'Laborbuch.csv');
    cfg.pfade.ausgabe    = fullfile(wurzel, 'output');             % CSV-Ergebnisse
    cfg.pfade.abbildungen = fullfile(wurzel, 'output', 'abbildungen'); % Methodik-Abbildungen (Abb1–9)

    %% Video
    cfg.video.dateimuster = 'XSM-3520 Camera 0330_*.avi';  % Dateiname der Kamera-AVIs
    cfg.video.fps         = 200;                            % Bildrate [1/s], nur wenn der Pfad kein "<n>fps" enthält

    %% Kalibrierung (Lineal im ersten Frame des Kalibriervideos)
    cfg.kalibrierung.ordnermuster        = 'Kalibrierung_*';
    cfg.kalibrierung.rasterweite_mm      = 0.525;  % Abstand zweier Linealstriche [mm]
    cfg.kalibrierung.suchbereich_rel     = [0.30 0.80]; % vertikaler Suchstreifen [Anteil Bildhöhe]
    cfg.kalibrierung.band_oben_px        = 60;     % Band über der stärksten Kantenzeile [px]
    cfg.kalibrierung.band_unten_px       = 15;     % Band darunter [px]
    cfg.kalibrierung.rand_px             = 25;     % ignorierter Bildrand links/rechts [px]
    cfg.kalibrierung.glaettung_px        = 5;      % Fensterbreite Gauß-Glättung des Profils [px]
    cfg.kalibrierung.prominenz_rel       = 0.10;   % Mindestprominenz eines Strichs [Anteil Maximum]
    cfg.kalibrierung.min_strichabstand_px = 8;     % [px]
    cfg.kalibrierung.min_striche         = 10;     % Mindestanzahl erkannter Striche
    cfg.kalibrierung.raster_toleranz_rel = 0.25;   % zulässige Abweichung vom Median-Abstand

    %% Detektion (je Frame)
    cfg.detektion.sens            = 0.95;   % Sensitivität adaptthresh [0..1]; höher = mehr Vordergrund
    cfg.detektion.clahe_kacheln   = [4 8];  % adapthisteq NumTiles
    cfg.detektion.clahe_clip      = 0.01;   % adapthisteq ClipLimit
    cfg.detektion.median_px       = [3 3];  % Medianfilter [px]
    cfg.detektion.close_hoehe_px  = 5;      % imclose vertikal [px]
    cfg.detektion.close_breite_px = 5;      % imclose horizontal [px]
    cfg.detektion.staub_px        = 15;     % kleinste schwarze Störfläche im Slug [px²]
    cfg.detektion.min_slug_px     = 50;     % kleinste weiße Slug-Fläche nach dem Füllen [px²]
    cfg.detektion.min_flaeche_px  = 100;    % kleinste Objektfläche für die Kanalhöhe [px²]
    cfg.detektion.band_halb_px    = 2;      % halbe Breite des Bands um die Mittellinie [px]
    cfg.detektion.strahl_max_px   = 20;     % maximale Raycasting-Suchweite [px]
    cfg.detektion.strahl_anteil   = 0.8;    % Anteil der Strecke bis zur Nachbarkante
    cfg.detektion.strahl_min_px   = 2;      % minimale Raycasting-Suchweite [px]
    cfg.detektion.abstand_ersatz_px = 50;   % Ersatz-Kantenabstand, wenn kein Median bestimmbar [px]
    cfg.detektion.min_blase_px    = 5;      % Blasen bis zu dieser Länge werden verworfen [px]
    cfg.detektion.randabstand_px  = 2;      % Unit-Cells am Bildrand verwerfen [px]

    %% Kanalmodell (über die ersten Frames geschätzt, danach fest)
    cfg.kanal.init_frames      = 10;    % Frames für die Schätzung
    cfg.kanal.stuetzabstand_px = 20;    % Abstand der Stützstellen [px]
    cfg.kanal.min_gueltig_rel  = 0.3;   % Mindestanteil gültiger Stützstellen je Frame
    cfg.kanal.breite_tol_rel   = 0.08;  % Toleranz Kanalbreite [Anteil Median]
    cfg.kanal.sprung_rel       = 0.05;  % Sprungschwelle Randkurve [Anteil Median]
    cfg.kanal.kruemmung_rel    = 0.03;  % Krümmungsschwelle [Anteil Median]
    cfg.kanal.streuung_rel     = 0.04;  % Streuungsschwelle über Frames [Anteil Median]
    cfg.kanal.min_hoehe_rel    = 0.85;  % Ersatzmodell: Mindesthöhe [Anteil Median]

    %% Tracking
    cfg.tracking.max_sprung_px  = 50;   % größte Verschiebung je Frame [px]
    cfg.tracking.rueckwaerts_px = 2;    % tolerierte Rückwärtsbewegung (Rauschen) [px]
    cfg.tracking.min_frames     = 10;   % Blasen mit weniger Frames werden verworfen

    %% Laborbuch-Korrekturen
    % Druckkalibrierungen laufen ohne CO2; das Laborbuch trägt dort 0,2 ein.
    % NaN = Laborbuchwert unverändert übernehmen.
    cfg.laborbuch.co2_anteil_druck = 0;

    %% Physik
    cfg.physik.bin_mm          = 4;     % Bin-Breite [mm]; wird auf ceil(2·L_B)/2 vergrößert, wenn kleiner als L_B
    cfg.physik.v_max_m_s       = 5;     % größte plausible Geschwindigkeit [m/s]
    cfg.physik.plateau_rel     = [0.20 0.80]; % Referenzbereich der Bins für das Plateau
    cfg.physik.plateau_schwelle = 0.50; % Bin gilt, wenn Anzahl >= Schwelle · Median

    %% Einlauflänge L_ein = faktor · Re · d_h (Blasen davor werden verworfen)
    cfg.einlauf.rho_kg_m3 = 1000;    % Dichte der kontinuierlichen Phase (Wasser)
    cfg.einlauf.mu_Pa_s   = 0.001;   % Viskosität der kontinuierlichen Phase (Wasser)
    cfg.einlauf.faktor    = 0.05;

    %% Methodik-Abbildungen (Abb1–9 eines Frames)
    cfg.abbildungen.exportieren = false;
    cfg.abbildungen.frame       = 15;
    cfg.abbildungen.dpi         = 600;
    cfg.abbildungen.bemassung_px = 45;   % Höhe der Bemaßungslinie über der Blase [px]

    %% Plots
    cfg.plots.sprache  = 'de';           % 'de' oder 'en'
    cfg.plots.breite_cm = 16;
    cfg.plots.hoehe_cm  = 9;
    cfg.plots.formate  = {'png', 'pdf'};
    cfg.plots.dpi      = 300;
    cfg.plots.batch    = true;           % Verlaufsplots je Setup nach dem Batch erzeugen

    %% Anzeige (Live-Ansicht, Kalibrierkontrolle)
    cfg.anzeige.live          = false;   % Live-Ansicht während der Auswertung
    cfg.anzeige.jedes_n_frame = 10;
    cfg.anzeige.kalibrierung  = false;   % Kalibrierkontrolle anzeigen

    %% GUI-Startwerte
    cfg.gui.sens_start = 0.85;
    cfg.gui.sens_ende  = 0.95;
    cfg.gui.sens_schritt = 0.05;
end
