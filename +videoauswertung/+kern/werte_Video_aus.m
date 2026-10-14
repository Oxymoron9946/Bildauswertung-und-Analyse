function erg = werte_Video_aus(video, kalibVideo, kanalstart_mm, cfg, rueckmeldung)
% WERTE_VIDEO_AUS Wertet ein Messvideo vollständig aus.
%
% Bildrate: aus "<fps>fps" im Videopfad, sonst cfg.video.fps.
% Kalibrierung aus dem ersten Frame des Kalibriervideos, danach je Frame
% Detektion (erkenne_Blasen) und Zuordnung (verfolge_Blasen), am Ende
% Geschwindigkeiten, Längen und Bins (berechne_Physik).
%
% Parameter
% ---------
% video : Pfad zum Messvideo (.avi)
% kalibVideo : Pfad zum Kalibriervideo (.avi)
% kanalstart_mm : Position des rechten Bildrands im Reaktor [mm] (Laborbuch "Offset")
% cfg : struct aus config()
% rueckmeldung : optional, struct mit Funktionen (alle optional):
%     kalibrierung(frame, info, px2mm, ok)  nach der Kalibrierung
%     live(I, seeds, det, px2mm, frame)      jedes cfg.anzeige.jedes_n_frame-te Frame
%     abbruch() -> logical                   wird zusammen mit live geprüft
%
% Rückgabe
% --------
% erg : struct mit rohdaten, bins (siehe berechne_Physik), px2mm [mm/px],
%       mean_UC_mm (mittlere Unit-Cell-Länge [mm]), L_ein_mm, frames,
%       abgebrochen (logical)

    if nargin < 5 || isempty(rueckmeldung)
        rueckmeldung = struct();
    end

    %% Kalibrierung
    vk = VideoReader(kalibVideo);
    kalibFrame = graustufen(readFrame(vk));
    [px2mm, ok, info] = videoauswertung.kern.kalibriere_Massstab(kalibFrame, cfg);
    if isfield(rueckmeldung, 'kalibrierung')
        rueckmeldung.kalibrierung(kalibFrame, info, px2mm, ok);
    end
    if ~ok || isnan(px2mm)
        error('videoauswertung:kalibrierung', ...
            'Automatische Kalibrierung fehlgeschlagen (%s). Abbruch der Auswertung.', kalibVideo);
    end

    %% Frame-Schleife
    v = VideoReader(video);
    v.CurrentTime = 0;
    imgW = v.Width;
    kanal = [];
    verlauf = [];
    naechsteID = 1;
    vorher = [];
    uc_mm = [];
    frame = 0;
    abgebrochen = false;
    zeigeLive = cfg.anzeige.live && isfield(rueckmeldung, 'live');

    while hasFrame(v)
        frame = frame + 1;
        I = graustufen(readFrame(v));

        [blasen, kanal, det, uc_px, B_vorher, B_nachher, seeds] = ...
            videoauswertung.kern.erkenne_Blasen(I, kanal, cfg);
        if ~isempty(uc_px)
            uc_mm = [uc_mm; uc_px * px2mm]; %#ok<AGROW>
        end
        [verlauf, vorher, naechsteID] = videoauswertung.kern.verfolge_Blasen( ...
            blasen, vorher, verlauf, naechsteID, frame, cfg);

        if cfg.abbildungen.exportieren && frame == cfg.abbildungen.frame
            videoauswertung.plots.exportiere_Methodik(I, B_vorher, B_nachher, seeds, det, px2mm, cfg);
        end

        if zeigeLive && mod(frame, cfg.anzeige.jedes_n_frame) == 0
            rueckmeldung.live(I, seeds, det, px2mm, frame);
            if isfield(rueckmeldung, 'abbruch') && rueckmeldung.abbruch()
                abgebrochen = true;
                break;
            end
        end
    end

    %% Physik
    m = videoauswertung.kern.lies_Messlauf(video);
    fps = cfg.video.fps;
    if ~isnan(m.fps)
        fps = m.fps;
    end
    L_ein_mm = videoauswertung.kern.einlauflaenge(m, cfg);
    [rohdaten, bins] = videoauswertung.kern.berechne_Physik(verlauf, px2mm, fps, ...
        imgW, kanalstart_mm, L_ein_mm, cfg);

    erg = struct('rohdaten', rohdaten, 'bins', bins, 'px2mm', px2mm, ...
        'mean_UC_mm', mean_oder_nan(uc_mm), 'L_ein_mm', L_ein_mm, 'frames', frame, ...
        'abgebrochen', abgebrochen);
end

function I = graustufen(I)
    if ndims(I) == 3
        I = rgb2gray(I);
    end
end

function w = mean_oder_nan(x)
    if isempty(x)
        w = NaN;
    else
        w = mean(x);
    end
end
