function bericht = vergleiche_Ergebnisse(vorherDir, nachherDir, berichtDatei)
% VERGLEICHE_ERGEBNISSE Vorher/Nachher-Vergleich zweier Ergebnisordner.
%
% Für jede CSV in vorherDir wird die entsprechende Datei in nachherDir
% gesucht (gleicher relativer Pfad, sonst die einzige CSV im selben
% Unterordner). Verglichen wird auf zwei Ebenen:
%   Bins:   Zeilen mit gleichem Video-Schlüssel und gleicher Bin-Mitte
%   Videos: mit GroupCount gewichtetes Mittel je Video
% Je Größe: Median und Maximum der absoluten und relativen Abweichung.
%
% Parameter
% ---------
% vorherDir, nachherDir : Ergebnisordner (z. B. _archiv/baseline_0cf713b)
% berichtDatei : optional, Markdown-Datei für den Bericht
%
% Rückgabe
% --------
% bericht : table, eine Zeile je Datei und Größe

    groessen = {'mean_BubbleLength_mm', 'mean_UnitCellLength_mm', 'mean_SlugLength_mm', ...
        'mean_VoidFraction', 'mean_Speed_m_s', 'GroupCount'};
    dateien = dir(fullfile(vorherDir, '**', '*.csv'));
    zeilen = {};
    text = strings(0, 1);
    for d = 1:numel(dateien)
        vorher = fullfile(dateien(d).folder, dateien(d).name);
        rel = erase(vorher, [char(java.io.File(vorherDir).getCanonicalPath()) filesep]);
        nachher = finde_Gegenstueck(vorherDir, nachherDir, vorher);
        if isempty(nachher)
            text(end+1) = sprintf('- `%s`: kein Gegenstück im Nachher-Ordner', rel); %#ok<AGROW>
            continue;
        end
        A = lies(vorher);
        B = lies(nachher);
        schluessel = intersect(intersect({'GasVelocity', 'LiquidVelocity', 'CameraPosition', 'Material', ...
            'Geometrie', 'Kanal_um', 'Nadel_um', 'Messart', 'Aufnahme', 'UsedSensitivity'}, ...
            A.Properties.VariableNames, 'stable'), B.Properties.VariableNames, 'stable');
        A.schluessel = video_Schluessel(A, schluessel);
        B.schluessel = video_Schluessel(B, schluessel);

        % Bins
        [~, ia, ib] = intersect(compose('%s|%.10g', A.schluessel, A.BinCenter_mm), ...
            compose('%s|%.10g', B.schluessel, B.BinCenter_mm));
        % Videos
        [videos, ~, ka] = unique(A.schluessel);
        [~, kb] = ismember(B.schluessel, videos);
        nurNeu = numel(unique(B.schluessel(kb == 0)));
        text(end+1) = sprintf(['\n### `%s`\n\nZeilen vorher/nachher: %d / %d; gemeinsame Bins: %d; ' ...
            'Videos: %d (neu nur nachher: %d)\n\n| Größe | Bins Median abs | Bins Max abs | Bins Max rel %% | ' ...
            'Videos Median abs | Videos Max abs | Videos Max rel %% |\n|---|---|---|---|---|---|---|'], ...
            rel, height(A), height(B), numel(ia), numel(videos), nurNeu); %#ok<AGROW>
        for g = groessen
            q = g{1};
            if ~ismember(q, A.Properties.VariableNames) || ~ismember(q, B.Properties.VariableNames)
                continue;
            end
            dBin = B.(q)(ib) - A.(q)(ia);
            rBin = abs(dBin) ./ abs(A.(q)(ia)) * 100;
            mA = gewichtet(A.(q), A.GroupCount, ka, numel(videos));
            mB = gewichtet(B.(q)(kb > 0), B.GroupCount(kb > 0), kb(kb > 0), numel(videos));
            dVid = mB - mA;
            rVid = abs(dVid) ./ abs(mA) * 100;
            zeile = {rel, q, numel(ia), median(abs(dBin), 'omitnan'), max(abs(dBin), [], 'omitnan'), ...
                max(rBin, [], 'omitnan'), median(abs(dVid), 'omitnan'), max(abs(dVid), [], 'omitnan'), ...
                max(rVid, [], 'omitnan')};
            zeilen(end+1, :) = zeile; %#ok<AGROW>
            text(end+1) = sprintf('| %s | %.4g | %.4g | %.3g | %.4g | %.4g | %.3g |', q, zeile{4:9}); %#ok<AGROW>
        end
    end
    bericht = cell2table(zeilen, 'VariableNames', {'Datei', 'Groesse', 'GemeinsameBins', ...
        'Bins_Median_abs', 'Bins_Max_abs', 'Bins_Max_rel_Prozent', 'Videos_Median_abs', ...
        'Videos_Max_abs', 'Videos_Max_rel_Prozent'});
    if nargin >= 3 && ~isempty(berichtDatei)
        fid = fopen(berichtDatei, 'w', 'n', 'UTF-8');
        fprintf(fid, '%s\n', text);
        fclose(fid);
    end
    fprintf('%s\n', text);
end

function T = lies(datei)
    T = readtable(datei, 'VariableNamingRule', 'preserve', 'TextType', 'string');
end

function k = video_Schluessel(T, spalten)
    if isempty(spalten)
        k = repmat("datei", height(T), 1);
        return;
    end
    teile = strings(height(T), numel(spalten));
    for s = 1:numel(spalten)
        teile(:, s) = string(T.(spalten{s}));
    end
    k = join(teile, '|', 2);
end

function m = gewichtet(werte, gewichte, gruppe, n)
    m = nan(n, 1);
    for i = 1:n
        sel = gruppe == i & ~isnan(werte);
        if any(sel)
            m(i) = sum(werte(sel) .* gewichte(sel)) / sum(gewichte(sel));
        end
    end
end

function nachher = finde_Gegenstueck(vorherDir, nachherDir, vorher)
    basisV = char(java.io.File(vorherDir).getCanonicalPath());
    rel = erase(char(java.io.File(vorher).getCanonicalPath()), [basisV filesep]);
    nachher = fullfile(nachherDir, rel);
    if isfile(nachher)
        return;
    end
    kandidaten = dir(fullfile(nachherDir, fileparts(rel), '*.csv'));
    geschwister = dir(fullfile(fileparts(vorher), '*.csv'));
    if isscalar(kandidaten) && isscalar(geschwister)
        nachher = fullfile(kandidaten.folder, kandidaten.name);
    else
        nachher = '';
    end
end
