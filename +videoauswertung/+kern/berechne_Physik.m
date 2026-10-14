function [rohdaten, bins] = berechne_Physik(verlauf, px2mm, fps, imgW, kanalstart_mm, L_ein_mm, cfg)
% BERECHNE_PHYSIK Geschwindigkeiten und Längen je Blase, gemittelt in Bins.
%
% Schritte
% --------
% 1. Je Blase (mindestens cfg.tracking.min_frames Frames): v = -dx/dt
%    zwischen aufeinanderfolgenden Frames, Längen als Mittel beider Frames,
%    Position = Mittelwert der x-Positionen minus halbe Blasenlänge.
%    Nur 0 < v < cfg.physik.v_max_m_s.
% 2. Position im Reaktor: kanalstart_mm + Abstand vom rechten Bildrand.
%    Punkte vor der Einlauflänge L_ein_mm werden verworfen.
% 3. Bins der Breite cfg.physik.bin_mm (vergrößert auf ceil(2·L_B)/2 mm,
%    wenn die Bin-Breite kleiner ist als die mittlere Blasenlänge L_B).
% 4. Plateau: Bins mit mindestens cfg.physik.plateau_schwelle × Median der
%    Anzahl im Referenzbereich cfg.physik.plateau_rel; längster
%    zusammenhängender Bereich. Nur dieser geht in die Statistik.
%
% Parameter
% ---------
% verlauf : [K x 5] [ID, Frame, x_px, Blasenlänge_px, UC-Länge_px]
% px2mm : Maßstab [mm/px]
% fps : Bildrate [1/s]
% imgW : Bildbreite [px]
% kanalstart_mm : Position des rechten Bildrands im Reaktor [mm]
% L_ein_mm : Einlauflänge [mm] (NaN = kein Filter)
% cfg : struct aus config()
%
% Rückgabe
% --------
% rohdaten : table je Messpunkt (BubbleID, Position_X_mm, Speed_m_s,
%            BubbleLength_mm, UnitCellLength_mm, SlugLength_mm,
%            VoidFraction, BinCenter_mm)
% bins : table je Bin (grpstats: mean_/std_/numel_ je Größe, GroupCount);
%        UserData: validStart, validEnd, firstMeas [mm]

    if isempty(verlauf) || size(verlauf, 2) < 5
        rohdaten = table();
        bins = table();
        return;
    end

    [ids, x_mm_px, v, L_B, L_UC, L_S, eps_v] = je_Blase(verlauf, px2mm, fps, cfg);

    % Position im Reaktor
    pos_mm = kanalstart_mm + (imgW - x_mm_px) * px2mm;
    if ~isnan(L_ein_mm) && L_ein_mm > 0
        ok = pos_mm >= L_ein_mm;
        ids = ids(ok); pos_mm = pos_mm(ok); v = v(ok);
        L_B = L_B(ok); L_UC = L_UC(ok); L_S = L_S(ok); eps_v = eps_v(ok);
    end

    rohdaten = table(ids, pos_mm, v, L_B, L_UC, L_S, eps_v, ...
        'VariableNames', {'BubbleID', 'Position_X_mm', 'Speed_m_s', ...
        'BubbleLength_mm', 'UnitCellLength_mm', 'SlugLength_mm', 'VoidFraction'});
    if isempty(rohdaten)
        bins = table();
        return;
    end

    % Bins
    bin_mm = cfg.physik.bin_mm;
    if bin_mm < mean(L_B)
        bin_mm = ceil(mean(L_B) * 2) / 2;
    end
    kanten = (floor(min(pos_mm)/bin_mm) * bin_mm):bin_mm:(ceil(max(pos_mm)/bin_mm) * bin_mm);
    [anzahl, ~, binIdx] = histcounts(pos_mm, kanten);
    mitten = kanten(1:end-1) + bin_mm/2;
    rohdaten.BinCenter_mm = mitten(binIdx)';

    [start_mm, ende_mm] = plateau(anzahl, kanten, cfg);
    imPlateau = (pos_mm >= start_mm) & (pos_mm <= ende_mm);
    if isnan(start_mm)
        warning('Keine stabile Messzone gefunden.');
        imPlateau = false(size(pos_mm));
    end

    bins = grpstats(rohdaten(imPlateau, :), 'BinCenter_mm', {'mean', 'std', 'numel'}, ...
        'DataVars', {'BubbleLength_mm', 'UnitCellLength_mm', 'SlugLength_mm', 'VoidFraction', 'Speed_m_s'});
    bins.Properties.UserData = struct('validStart', start_mm, 'validEnd', ende_mm, ...
        'firstMeas', min(pos_mm));
end

function [ids, x_px, v, L_B, L_UC, L_S, eps_v] = je_Blase(verlauf, px2mm, fps, cfg)
    ids = []; x_px = []; v = []; L_B = []; L_UC = []; L_S = []; eps_v = [];
    for bID = unique(verlauf(:, 1))'
        idx = find(verlauf(:, 1) == bID);
        if length(idx) < cfg.tracking.min_frames
            continue;   % zu kurz verfolgt: meist Fehlerkennung
        end
        spur = sortrows(verlauf(idx, :), 2);
        frames = spur(:, 2);
        x      = spur(:, 3);
        lb     = spur(:, 4);
        luc    = spur(:, 5);

        % Geschwindigkeit zwischen zwei Frames; Minus, weil x stromab abnimmt
        v_m_s = ((-diff(x) * px2mm) ./ (diff(frames) / fps)) / 1000;
        mitte_x  = (x(1:end-1) + x(2:end)) / 2;
        mitte_lb = (lb(1:end-1) + lb(2:end)) / 2;
        mitte_uc = (luc(1:end-1) + luc(2:end)) / 2;
        mitte_x  = mitte_x - (mitte_lb / 2);   % siehe Befund F02

        ok = (v_m_s > 0) & (v_m_s < cfg.physik.v_max_m_s);
        if sum(ok) == 0
            continue;
        end
        lb_mm = mitte_lb(ok) * px2mm;
        uc_mm = mitte_uc(ok) * px2mm;

        ids  = [ids; repmat(bID, sum(ok), 1)]; %#ok<AGROW>
        x_px = [x_px; mitte_x(ok)]; %#ok<AGROW>
        v    = [v; v_m_s(ok)]; %#ok<AGROW>
        L_B  = [L_B; lb_mm]; %#ok<AGROW>
        L_UC = [L_UC; uc_mm]; %#ok<AGROW>
        L_S  = [L_S; uc_mm - lb_mm]; %#ok<AGROW>
        eps_v  = [eps_v; lb_mm ./ uc_mm]; %#ok<AGROW>
    end
end

function [start_mm, ende_mm] = plateau(anzahl, kanten, cfg)
    n = numel(anzahl);
    start_mm = NaN;
    ende_mm = NaN;
    if n < 3
        return;
    end
    i0 = max(1, round(cfg.physik.plateau_rel(1) * n));
    i1 = min(n, round(cfg.physik.plateau_rel(2) * n));
    gueltig = anzahl >= cfg.physik.plateau_schwelle * median(anzahl(i0:i1));
    d = diff([false gueltig false]);
    anfaenge = find(d == 1);
    enden = find(d == -1) - 1;
    if isempty(anfaenge)
        return;
    end
    [~, k] = max(enden - anfaenge);
    start_mm = kanten(anfaenge(k));
    ende_mm = kanten(enden(k) + 1);
end
