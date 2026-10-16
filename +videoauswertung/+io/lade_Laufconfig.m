function [cfg, lauf] = lade_Laufconfig(datei)
% LADE_LAUFCONFIG Liest die Einstellungen eines früheren Laufs.
%
% Grundlage ist das aktuelle config(); alle in der Datei gespeicherten
% Einträge überschreiben es. Einträge, die es in config() nicht mehr gibt,
% werden mit Warnung ignoriert; neue Einträge behalten ihren Standardwert.
%
% Parameter
% ---------
% datei : lauf_config_<Zeit>.json (schreibe_Laufconfig)
%
% Rückgabe
% --------
% cfg : struct wie aus config()
% lauf : struct mit art, ziel, zeit, commit

    inhalt = jsondecode(fileread(datei));
    lauf = inhalt.lauf;
    cfg = uebernimm(config(), inhalt.cfg, 'cfg');
end

function ziel = uebernimm(ziel, quelle, pfad)
    for name = fieldnames(quelle)'
        n = name{1};
        if ~isfield(ziel, n)
            warning('videoauswertung:laufconfig', 'Unbekannter Eintrag %s.%s wird ignoriert.', pfad, n);
            continue;
        end
        if isstruct(ziel.(n)) && isstruct(quelle.(n))
            ziel.(n) = uebernimm(ziel.(n), quelle.(n), [pfad '.' n]);
        elseif iscell(ziel.(n))
            ziel.(n) = reshape(cellstr(quelle.(n)), 1, []);   % JSON-Listen kommen als Spalte zurück
        elseif isnumeric(ziel.(n)) || islogical(ziel.(n))
            wert = quelle.(n);
            if numel(wert) == numel(ziel.(n))
                wert = reshape(wert, size(ziel.(n)));
            else
                wert = reshape(wert, 1, []);
            end
            ziel.(n) = cast(wert, class(ziel.(n)));
        else
            ziel.(n) = quelle.(n);
        end
    end
end
