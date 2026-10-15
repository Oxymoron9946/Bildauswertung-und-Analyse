function datei = schreibe_Laufconfig(cfg, art, ziel)
% SCHREIBE_LAUFCONFIG Speichert alle Einstellungen eines Laufs als JSON.
%
% Datei: <cfg.pfade.ausgabe>/lauf_config_<yyyyMMdd_HHmmss>.json mit
%   lauf.art   'batch' oder 'einzel'
%   lauf.ziel  Messordner bzw. Messvideo
%   lauf.zeit  Zeitstempel
%   lauf.commit  git-Stand des Codes (falls verfügbar)
%   cfg        vollständige Einstellungen
% Wiederholen: videoauswertung.kern.wiederhole_Lauf(datei)
%
% Parameter
% ---------
% cfg : struct aus config() (wie im Lauf verwendet)
% art : 'batch' oder 'einzel'
% ziel : Messordner oder Messvideo
%
% Rückgabe
% --------
% datei : geschriebene JSON-Datei

    zeit = datetime('now');
    inhalt.lauf = struct('art', art, 'ziel', char(ziel), ...
        'zeit', char(zeit, 'yyyy-MM-dd HH:mm:ss'), 'commit', git_Stand(cfg.pfade.projekt));
    inhalt.cfg = cfg;
    if ~isfolder(cfg.pfade.ausgabe)
        mkdir(cfg.pfade.ausgabe);
    end
    datei = fullfile(cfg.pfade.ausgabe, sprintf('lauf_config_%s.json', char(zeit, 'yyyyMMdd_HHmmss')));
    fid = fopen(datei, 'w', 'n', 'UTF-8');
    fprintf(fid, '%s', jsonencode(inhalt, 'PrettyPrint', true));
    fclose(fid);
    fprintf('Einstellungen des Laufs: %s\n', datei);
end

function stand = git_Stand(projekt)
    [status, ausgabe] = system(sprintf('git -C "%s" describe --always --dirty', projekt));
    if status == 0
        stand = strtrim(ausgabe);
    else
        stand = '';
    end
end
