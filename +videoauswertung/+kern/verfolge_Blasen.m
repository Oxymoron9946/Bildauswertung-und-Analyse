function [verlauf, vorher, naechsteID] = verfolge_Blasen(blasen, vorher, verlauf, naechsteID, frame, cfg)
% VERFOLGE_BLASEN Ordnet die Blasen eines Frames den Blasen des Vorframes zu.
%
% Eine Blase übernimmt die ID der Vorframe-Blase mit dem kleinsten
% plausiblen Vorwärtssprung (Strömung rechts -> links):
%   -cfg.tracking.rueckwaerts_px <= x_vorher - x_jetzt < cfg.tracking.max_sprung_px
% Ohne Treffer erhält sie eine neue ID. Enthält ein Frame keine Blase,
% beginnt die Zuordnung im nächsten Frame neu.
%
% Parameter
% ---------
% blasen : [N x 3] aus erkenne_Blasen ([x_px, Blasenlänge_px, UC-Länge_px])
% vorher : [M x 2] [ID, x_px] des Vorframes
% verlauf : [K x 5] bisheriges Protokoll [ID, Frame, x_px, Blasenlänge_px, UC-Länge_px]
% naechsteID : nächste freie ID
% frame : Framenummer (Zeitstempel)
% cfg : struct aus config()
%
% Rückgabe
% --------
% verlauf, vorher, naechsteID : aktualisiert

    if isempty(blasen)
        vorher = [];
        return;
    end

    neu = [];
    for c = 1:size(blasen, 1)
        x = blasen(c, 1);
        id = -1;
        if ~isempty(vorher)
            dx = vorher(:, 2) - x;
            kandidaten = find(dx >= -cfg.tracking.rueckwaerts_px & dx < cfg.tracking.max_sprung_px);
            if ~isempty(kandidaten)
                [~, k] = min(dx(kandidaten));
                bester = kandidaten(k);
                id = vorher(bester, 1);
                vorher(bester, :) = [];   % nicht ein zweites Mal vergeben
            end
        end
        if id == -1
            id = naechsteID;
            naechsteID = naechsteID + 1;
        end
        verlauf = [verlauf; id, frame, x, blasen(c, 2), blasen(c, 3)]; %#ok<AGROW>
        neu = [neu; id, x]; %#ok<AGROW>
    end
    vorher = neu;
end
