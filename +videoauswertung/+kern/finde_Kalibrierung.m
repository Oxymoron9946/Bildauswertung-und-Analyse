function kalib = finde_Kalibrierung(video, cfg)
% FINDE_KALIBRIERUNG Kalibriervideo zu einem Messvideo.
%
% Gesucht wird unterhalb des Ordners der Kalibriergruppe "Pos_<n>_Kal_<k>",
% in dem das Messvideo liegt, in Ordnern nach cfg.kalibrierung.ordnermuster.
% Es muss genau ein Kalibriervideo geben; sonst bricht die Funktion ab.
% (Vorher galt im Batch das zuletzt gefundene Video derselben Gruppe aus
% beliebigen Teilordnern, Befund F01.)
%
% Parameter
% ---------
% video : Pfad zum Messvideo
% cfg : struct aus config()
%
% Rückgabe
% --------
% kalib : Pfad zum Kalibriervideo

    m = videoauswertung.kern.lies_Messlauf(video);
    if isempty(m.gruppe)
        error('videoauswertung:keineGruppe', ...
            'Der Videopfad enthält keinen Ordner "Pos_<n>_Kal_<k>": %s', video);
    end
    basis = char(video);
    while true
        [eltern, ordner, endung] = fileparts(basis);
        if strcmp([ordner endung], m.gruppe)
            break;
        end
        if isempty(eltern) || strcmp(eltern, basis)
            error('videoauswertung:keineGruppe', 'Ordner "%s" nicht im Videopfad gefunden: %s', m.gruppe, video);
        end
        basis = eltern;
    end
    liste = dir(fullfile(basis, '**', cfg.kalibrierung.ordnermuster, '*.avi'));
    if isempty(liste)
        error('videoauswertung:keineKalibrierung', 'Kein Kalibriervideo unter %s.', basis);
    elseif numel(liste) > 1
        error('videoauswertung:mehrdeutigeKalibrierung', ...
            'Mehrere Kalibriervideos unter %s:\n%s', basis, strjoin(fullfile({liste.folder}, {liste.name}), newline));
    end
    kalib = fullfile(liste.folder, liste.name);
end
