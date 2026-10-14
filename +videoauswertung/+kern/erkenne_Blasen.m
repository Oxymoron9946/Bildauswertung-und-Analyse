function [blasen, kanal, det, uc_px, B_vorher, B_nachher, seeds] = erkenne_Blasen(I, kanal, cfg)
% ERKENNE_BLASEN Findet Blasen und Unit-Cells in einem Frame des Taylor-Flows.
%
% Ablauf (Strömung von rechts nach links):
%   1. Kontrast (CLAHE) und Median, adaptive Schwelle, Schließen   -> B_vorher
%   2. Kanalränder: über cfg.kanal.init_frames Frames geschätzt, danach fest
%   3. Kanten auf der Mittellinie, je Kante Raycasting-Abstimmung:
%      Typ 1 = linke Blasenkante, Typ 2 = linke Slugkante
%   4. Alternanz 1/2/1/2 erzwingen (Störkanten nach Abstandsrhythmus entfernen)
%   5. Region Growing füllt die Blasen schwarz                       -> B_nachher
%   6. Blasen als schwarze Abschnitte auf der Mittellinie; durch Reflexionen
%      zerteilte Blasen wieder verbinden; Unit-Cells aus benachbarten Blasen
%
% Parameter
% ---------
% I : uint8-Matrix, Grauwertbild (volle Bildfläche)
% kanal : struct, frameübergreifender Zustand des Kanalmodells ([] beim ersten Frame)
% cfg : struct aus config()
%
% Rückgabe
% --------
% blasen : [N x 3] [x_px (Blasenmitte), Blasenlänge_px, Unit-Cell-Länge_px]
% kanal : aktualisierter Kanalzustand (u. a. heightEstimate [px], Randkurven)
% det : struct-Array der Blasen (cx, leftX, leftY, rightX, rightY, bb) [px]
% uc_px : [N x 1] Unit-Cell-Längen [px]
% B_vorher, B_nachher : logische Binärbilder vor/nach dem Füllen (Abbildungen)
% seeds : struct mit Zwischenergebnissen für Live-Ansicht und Abbildungen

    [imgH, imgW] = size(I);
    kanal = initialisiere_Kanal(kanal, cfg);
    blasen = [];
    uc_px = [];
    det = struct('cx', {}, 'leftX', {}, 'leftY', {}, 'rightX', {}, 'rightY', {}, 'bb', {});

    [I_eq, B_vorher] = binarisiere(I, cfg);

    seeds = struct('slug_cx', [], 'slug_cy', [], 'bub_cx', [], 'bub_cy', [], 'check_lines_x', [], ...
                   'top_points_x', [], 'top_points_y', [], 'bot_points_x', [], 'bot_points_y', []);
    [y_top, y_bot, kanal, seeds] = kanalraender(B_vorher, kanal, seeds, imgW, imgH, cfg);
    y_top = max(1, min(imgH, y_top));
    y_bot = max(1, min(imgH, y_bot));
    y_mid = (y_top + y_bot) / 2;

    % Staub im Slug entfernen, ohne die Blasenkappen anzugreifen
    B_clean = ~bwareaopen(~B_vorher, cfg.detektion.staub_px);

    seeds.slug_cx = []; seeds.slug_cy = [];
    seeds.bub_cx = []; seeds.bub_cy = [];
    seeds.tie_cx = []; seeds.tie_cy = [];
    seeds.center_cx = []; seeds.center_cy = [];
    seeds.ray_x = []; seeds.ray_y0 = []; seeds.ray_y1 = [];
    seeds.mid_line_y = y_mid;
    seeds.y_top_line = y_top;
    seeds.y_bot_line = y_bot;

    [kanten, seeds] = klassifiziere_Kanten(B_clean, y_mid, seeds, imgW, imgH, cfg);
    [kanten, seeds] = erzwinge_Alternanz(kanten, seeds, cfg);
    [B_nachher, seeds] = fuelle_Blasen(B_vorher, B_clean, y_mid, kanten, seeds, imgW, cfg);
    seeds.I_eq = I_eq;
    seeds.B_clean = B_clean;

    [kanal, weiter] = schaetze_Kanalhoehe(B_nachher, kanal, cfg);
    if ~weiter
        return;
    end

    [det, seeds] = blasen_auf_Mittellinie(B_nachher, y_mid, seeds, imgW, imgH, cfg);
    if cfg.detektion.fragmente_verbinden
        det = verbinde_Fragmente(det, cfg);
    end
    if numel(det) < 1
        return;
    end
    [blasen, uc_px] = unit_cells(det, imgW, cfg);
end

%% --- Schritt 1: Binarisierung -------------------------------------------

function [I_eq, B] = binarisiere(I, cfg)
    % CLAHE gleicht die Ausleuchtung entlang des Kanals an, der Median
    % entfernt Salz-und-Pfeffer-Rauschen an den Blasenkanten.
    I_eq = adapthisteq(I, 'NumTiles', cfg.detektion.clahe_kacheln, 'ClipLimit', cfg.detektion.clahe_clip);
    I_eq = medfilt2(I_eq, cfg.detektion.median_px);

    % Nachbarschaft der adaptiven Schwelle: halbe Bildhöhe, ungerade
    nbSize = floor(size(I_eq, 1) / 2);
    if mod(nbSize, 2) == 0
        nbSize = nbSize - 1;
    end
    T = adaptthresh(I_eq, cfg.detektion.sens, 'ForegroundPolarity', 'bright', 'NeighborhoodSize', [nbSize nbSize]);
    B = imbinarize(I_eq, T);

    % Risse in den (schwarzen) Blasen schließen: invertieren, schließen, zurück
    if cfg.detektion.close_hoehe_px > 1
        B = ~imclose(~B, strel('rectangle', [cfg.detektion.close_hoehe_px, 1]));
    end
    if cfg.detektion.close_breite_px > 1
        B = ~imclose(~B, strel('rectangle', [1, cfg.detektion.close_breite_px]));
    end
end

%% --- Schritt 2: Kanalränder ---------------------------------------------

function [y_top, y_bot, kanal, seeds] = kanalraender(B, kanal, seeds, imgW, imgH, cfg)
    if kanal.locked
        y_top = kanal.y_top_line;
        y_bot = kanal.y_bot_line;
        [seeds.top_points_x, seeds.top_points_y, seeds.bot_points_x, seeds.bot_points_y] = ...
            stuetzpunkte_aus_Linien(kanal.x_support, y_top, y_bot, cfg);
        return;
    end

    [raw_top_x, raw_top_y, raw_bot_x, raw_bot_y] = rohe_Kanalraender(B, imgW, imgH, cfg);
    if isempty(raw_top_x)
        y_top = ones(1, imgW);
        y_bot = imgH * ones(1, imgW);
        return;
    end
    seeds.top_points_x = raw_top_x;
    seeds.top_points_y = raw_top_y;
    seeds.bot_points_x = raw_bot_x;
    seeds.bot_points_y = raw_bot_y;

    if isempty(kanal.x_support)
        kanal.x_support = raw_top_x;
    end
    top_on_support = interp1(raw_top_x, raw_top_y, kanal.x_support, 'linear', NaN);
    bot_on_support = interp1(raw_bot_x, raw_bot_y, kanal.x_support, 'linear', NaN);

    minValid = max(3, round(cfg.kanal.min_gueltig_rel * numel(kanal.x_support)));
    nValid = sum(~isnan(top_on_support) & ~isnan(bot_on_support));
    if nValid >= minValid
        kanal.samplesTop = [kanal.samplesTop; top_on_support];
        kanal.samplesBot = [kanal.samplesBot; bot_on_support];
        kanal.frameCount = kanal.frameCount + 1;
    end

    if kanal.frameCount >= kanal.initFramesTarget
        % Genug Frames gesammelt: Modell aus Medianen bilden und sperren
        kanal = sperre_Kanalmodell(kanal, imgW, imgH, cfg);
        y_top = kanal.y_top_line;
        y_bot = kanal.y_bot_line;
        [seeds.top_points_x, seeds.top_points_y, seeds.bot_points_x, seeds.bot_points_y] = ...
            stuetzpunkte_aus_Linien(kanal.x_support, y_top, y_bot, cfg);
    elseif kanal.initAttempts > 2 * kanal.initFramesTarget
        % Zu wenige brauchbare Frames: Einzelbildschätzung festschreiben
        [y_top, y_bot, seeds] = kanalraender_Einzelbild(seeds, imgW, imgH, cfg);
        kanal = sperre_Kanalmodell(kanal, imgW, imgH, cfg, y_top, y_bot);
    elseif kanal.frameCount >= 1
        % Vorläufiges Modell aus den bisherigen Frames
        top_prov = median(kanal.samplesTop, 1, 'omitnan');
        bot_prov = median(kanal.samplesBot, 1, 'omitnan');
        y_top = interp1(kanal.x_support, top_prov, 1:imgW, 'pchip', 'extrap');
        y_bot = interp1(kanal.x_support, bot_prov, 1:imgW, 'pchip', 'extrap');
    else
        y_top = interp1(raw_top_x, raw_top_y, 1:imgW, 'pchip', 'extrap');
        y_bot = interp1(raw_bot_x, raw_bot_y, 1:imgW, 'pchip', 'extrap');
    end
end

function kanal = initialisiere_Kanal(kanal, cfg)
    vorgabe = struct( ...
        'locked', false, ...
        'initFramesTarget', cfg.kanal.init_frames, ...
        'frameCount', 0, ...
        'initAttempts', 0, ...
        'samplesTop', [], ...
        'samplesBot', [], ...
        'x_support', [], ...
        'y_top_line', [], ...
        'y_bot_line', [], ...
        'y_mid_line', [], ...
        'width_ref', [], ...
        'heightEstimate', NaN, ...
        'validTopMask', [], ...
        'validBotMask', []);
    % Jeder Aufruf zählt als Versuch, auch der erste (initAttempts = 1).
    if isempty(kanal) || ~isstruct(kanal)
        kanal = vorgabe;
    end
    fn = fieldnames(vorgabe);
    for k = 1:numel(fn)
        if ~isfield(kanal, fn{k})
            kanal.(fn{k}) = vorgabe.(fn{k});
        end
    end
    kanal.initAttempts = kanal.initAttempts + 1;
end

function [raw_top_x, raw_top_y, raw_bot_x, raw_bot_y] = rohe_Kanalraender(B, imgW, imgH, cfg)
    % Größte schwarze Region = Kanalhintergrund; ihr oberster und unterster
    % Pixel je Stützstelle ergibt die Randkurven.
    raw_top_x = [];
    raw_top_y = [];
    raw_bot_x = [];
    raw_bot_y = [];

    stats_black = regionprops(bwlabel(~B), 'Area', 'PixelList');
    if isempty(stats_black)
        return;
    end
    [~, max_idx] = max([stats_black.Area]);
    pixels = stats_black(max_idx).PixelList;

    x_check = 1:cfg.kanal.stuetzabstand_px:imgW;
    for i = 1:numel(x_check)
        idx = pixels(:, 1) == x_check(i);
        if any(idx)
            y_vals = pixels(idx, 2);
            raw_top_x(end+1) = x_check(i); %#ok<AGROW>
            raw_top_y(end+1) = min(y_vals); %#ok<AGROW>
            raw_bot_x(end+1) = x_check(i); %#ok<AGROW>
            raw_bot_y(end+1) = max(y_vals); %#ok<AGROW>
        end
    end

    if isempty(raw_top_x)
        raw_top_x = 1;
        raw_top_y = 1;
        raw_bot_x = 1;
        raw_bot_y = imgH;
    end
end

function kanal = sperre_Kanalmodell(kanal, imgW, imgH, cfg, y_top_in, y_bot_in)
    if nargin >= 6 && ~isempty(y_top_in) && ~isempty(y_bot_in)
        top_fixed = interp1(1:imgW, y_top_in, kanal.x_support, 'linear', 'extrap');
        bot_fixed = interp1(1:imgW, y_bot_in, kanal.x_support, 'linear', 'extrap');
        validTop = true(size(top_fixed));
        validBot = true(size(bot_fixed));
        medianWidth = median(bot_fixed - top_fixed, 'omitnan');
    else
        top_med = median(kanal.samplesTop, 1, 'omitnan');
        bot_med = median(kanal.samplesBot, 1, 'omitnan');
        width_profile = bot_med - top_med;
        medianWidth = median(width_profile, 'omitnan');
        if isnan(medianWidth) || medianWidth <= 0
            medianWidth = max(imgH * 0.1, 10);
        end
        [top_fixed, bot_fixed, validTop, validBot] = repariere_Raender( ...
            top_med, bot_med, width_profile, medianWidth, kanal.samplesTop, kanal.samplesBot, ...
            kanal.x_support, cfg);
    end

    y_top = interp1(kanal.x_support, top_fixed, 1:imgW, 'pchip', 'extrap');
    y_bot = interp1(kanal.x_support, bot_fixed, 1:imgW, 'pchip', 'extrap');
    y_top = max(1, min(imgH, y_top));
    y_bot = max(1, min(imgH, y_bot));

    kanal.y_top_line = y_top;
    kanal.y_bot_line = y_bot;
    kanal.y_mid_line = (y_top + y_bot) / 2;
    kanal.width_ref = bot_fixed - top_fixed;
    kanal.heightEstimate = medianWidth;
    kanal.validTopMask = validTop;
    kanal.validBotMask = validBot;
    kanal.locked = true;
end

function [top_fixed, bot_fixed, validTop, validBot] = repariere_Raender( ...
        top_med, bot_med, width_profile, medianWidth, samplesTop, samplesBot, x_support, cfg)
    % Stützstellen mit unplausibler Breite, Sprung, Krümmung oder Streuung
    % gelten als ungültig und werden aus der Gegenseite bzw. interpoliert ersetzt.
    n = numel(top_med);
    validTop = ~isnan(top_med);
    validBot = ~isnan(bot_med);

    widthTol   = max(3, cfg.kanal.breite_tol_rel * medianWidth);
    jumpThresh = max(3, cfg.kanal.sprung_rel * medianWidth);
    curvThresh = max(2, cfg.kanal.kruemmung_rel * medianWidth);
    stdThresh  = max(2, cfg.kanal.streuung_rel * medianWidth);

    topJump = nachbarsprung(top_med);
    botJump = nachbarsprung(bot_med);
    topCurv = zweite_Differenz(top_med);
    botCurv = zweite_Differenz(bot_med);

    if ~isempty(samplesTop) && size(samplesTop, 1) >= 2
        topStd = std(samplesTop, 0, 1, 'omitnan');
        botStd = std(samplesBot, 0, 1, 'omitnan');
        nanFracTop = mean(isnan(samplesTop), 1);
        nanFracBot = mean(isnan(samplesBot), 1);
        validTop = validTop & (topStd <= stdThresh) & (nanFracTop <= 0.5);
        validBot = validBot & (botStd <= stdThresh) & (nanFracBot <= 0.5);
    end

    badWidth = abs(width_profile - medianWidth) > widthTol;
    for i = 1:n
        if ~badWidth(i)
            continue;
        end
        scoreTop = topJump(i) + topCurv(i);
        scoreBot = botJump(i) + botCurv(i);
        if scoreTop > scoreBot
            validTop(i) = false;
        elseif scoreBot > scoreTop
            validBot(i) = false;
        else
            validTop(i) = false;
            validBot(i) = false;
        end
    end

    validTop = validTop & ~(topJump > jumpThresh | topCurv > curvThresh);
    validBot = validBot & ~(botJump > jumpThresh | botCurv > curvThresh);

    width_ref_local = lokale_Breite(width_profile, medianWidth, validTop & validBot);

    top_fixed = top_med;
    bot_fixed = bot_med;
    for i = 1:n
        if ~validTop(i) && validBot(i)
            top_fixed(i) = bot_fixed(i) - width_ref_local(i);
        elseif validTop(i) && ~validBot(i)
            bot_fixed(i) = top_fixed(i) + width_ref_local(i);
        end
    end

    anchorTop = validTop & ~isnan(top_fixed);
    if sum(anchorTop) >= 2
        top_fixed = interpoliere_Luecken(x_support, top_fixed, anchorTop);
    end
    anchorBot = validBot & ~isnan(bot_fixed);
    if sum(anchorBot) >= 2
        bot_fixed = interpoliere_Luecken(x_support, bot_fixed, anchorBot);
    end

    stillBad = isnan(top_fixed) | isnan(bot_fixed);
    if any(stillBad)
        top_fixed(stillBad) = top_med(stillBad);
        bot_fixed(stillBad) = bot_med(stillBad);
    end
end

function jumps = nachbarsprung(y)
    n = numel(y);
    jumps = zeros(1, n);
    for i = 1:n
        vals = [];
        if i > 1, vals(end+1) = y(i-1); end %#ok<AGROW>
        if i < n, vals(end+1) = y(i+1); end %#ok<AGROW>
        vals = vals(~isnan(vals));
        if ~isempty(vals) && ~isnan(y(i))
            jumps(i) = min(abs(y(i) - vals));
        end
    end
end

function curv = zweite_Differenz(y)
    n = numel(y);
    curv = zeros(1, n);
    if n < 3
        return;
    end
    d2 = abs(diff(y, 2));
    curv(2:end-1) = d2;
    curv(1) = d2(1);
    curv(end) = d2(end);
    curv(isnan(curv)) = 0;
end

function width_ref_local = lokale_Breite(width_profile, medianWidth, validPairMask)
    n = numel(width_profile);
    width_ref_local = medianWidth * ones(1, n);
    for i = 1:n
        idx = max(1, i-2):min(n, i+2);
        localVals = width_profile(idx);
        localVals = localVals(validPairMask(idx) & ~isnan(localVals));
        if ~isempty(localVals)
            width_ref_local(i) = median(localVals);
        end
    end
end

function y_fixed = interpoliere_Luecken(x, y, validMask)
    y_fixed = y;
    invalidIdx = find(~validMask & isnan(y_fixed));
    validIdx = find(validMask & ~isnan(y_fixed));
    if isempty(invalidIdx)
        return;
    end
    if numel(validIdx) < 2
        fillVal = median(y_fixed(validIdx), 'omitnan');
        if isnan(fillVal)
            fillVal = 0;
        end
        y_fixed(invalidIdx) = fillVal;
        return;
    end
    y_fixed(invalidIdx) = interp1(x(validIdx), y_fixed(validIdx), x(invalidIdx), 'pchip', 'extrap');
end

function [top_x, top_y, bot_x, bot_y] = stuetzpunkte_aus_Linien(x_support, y_top, y_bot, cfg)
    if isempty(x_support)
        x_support = 1:cfg.kanal.stuetzabstand_px:numel(y_top);
    end
    top_x = x_support;
    top_y = interp1(1:numel(y_top), y_top, x_support, 'linear', 'extrap');
    bot_x = x_support;
    bot_y = interp1(1:numel(y_bot), y_bot, x_support, 'linear', 'extrap');
end

function [y_top, y_bot, seeds] = kanalraender_Einzelbild(seeds, imgW, imgH, cfg)
    if numel(seeds.top_points_x) >= 3
        hoehen = seeds.bot_points_y - seeds.top_points_y;
        min_hoehe = median(hoehen) * cfg.kanal.min_hoehe_rel;
        for i = 2:numel(seeds.top_points_x)
            if hoehen(i) < min_hoehe
                % Die Seite mit dem größeren Sprung übernimmt den Vorgänger
                jump_top = abs(seeds.top_points_y(i) - seeds.top_points_y(i-1));
                jump_bot = abs(seeds.bot_points_y(i) - seeds.bot_points_y(i-1));
                if jump_top > jump_bot
                    seeds.top_points_y(i) = seeds.top_points_y(i-1);
                else
                    seeds.bot_points_y(i) = seeds.bot_points_y(i-1);
                end
                hoehen(i) = seeds.bot_points_y(i) - seeds.top_points_y(i);
            end
        end
        y_top = interp1(seeds.top_points_x, seeds.top_points_y, 1:imgW, 'pchip', 'extrap');
        y_bot = interp1(seeds.bot_points_x, seeds.bot_points_y, 1:imgW, 'pchip', 'extrap');
    else
        y_top = ones(1, imgW);
        y_bot = imgH * ones(1, imgW);
    end
end

%% --- Schritt 3: Kanten auf der Mittellinie klassifizieren ---------------

function [kanten, seeds] = klassifiziere_Kanten(B_clean, y_mid, seeds, imgW, imgH, cfg)
    % Kante = zusammenhängender schwarzer Abschnitt im Band um die Mittellinie.
    % Strahlen nach oben/unten links und rechts der Kante: Ist der freie
    % Weg rechts kürzer, liegt die Krümmung "(" vor (Typ 1, linke
    % Blasenkante), links kürzer ")" (Typ 2, linke Slugkante).
    profil = band_Profil(B_clean, y_mid, imgW, imgH, cfg);
    [L_edges, num_edges] = bwlabel(profil);
    kanten = struct('x', {}, 'y', {}, 'type', {});
    weiss = @(x) B_clean(round(y_mid(x)), x);

    for i = 1:num_edges
        x_edge = round(mean(find(L_edges == i)));
        y_edge = round(y_mid(x_edge));

        % Startpunkte: aus der dicken Kante heraus
        x_left_start = x_edge;
        while x_left_start > 1 && weiss(x_left_start) == 0
            x_left_start = x_left_start - 1;
        end
        x_right_start = x_edge;
        while x_right_start < imgW && weiss(x_right_start) == 0
            x_right_start = x_right_start + 1;
        end

        % Suchweite: bis zur nächsten Kante, begrenzt
        dist_left = 0;
        x_search = x_left_start;
        while x_search > 1 && weiss(x_search) == 1
            x_search = x_search - 1;
            dist_left = dist_left + 1;
        end
        dist_right = 0;
        x_search = x_right_start;
        while x_search < imgW && weiss(x_search) == 1
            x_search = x_search + 1;
            dist_right = dist_right + 1;
        end
        max_search = min([floor(dist_left * cfg.detektion.strahl_anteil), ...
                          floor(dist_right * cfg.detektion.strahl_anteil), cfg.detektion.strahl_max_px]);
        if max_search < cfg.detektion.strahl_min_px
            max_search = cfg.detektion.strahl_min_px;
        end

        stimmen_links_kuerzer = 0;
        stimmen_rechts_kuerzer = 0;
        for step = 1:max_search
            x_L = max(1, x_left_start - step);
            x_R = min(imgW, x_right_start + step);
            [y_up_L, y_down_L] = senkrechter_Strahl(B_clean, x_L, round(y_mid(x_L)), imgH);
            [y_up_R, y_down_R] = senkrechter_Strahl(B_clean, x_R, round(y_mid(x_R)), imgH);
            seeds.ray_x(end+1) = x_L; seeds.ray_y0(end+1) = y_up_L; seeds.ray_y1(end+1) = y_down_L;
            seeds.ray_x(end+1) = x_R; seeds.ray_y0(end+1) = y_up_R; seeds.ray_y1(end+1) = y_down_R;
            dist_vert_L = y_down_L - y_up_L;
            dist_vert_R = y_down_R - y_up_R;
            if dist_vert_R < dist_vert_L
                stimmen_rechts_kuerzer = stimmen_rechts_kuerzer + 1;
            elseif dist_vert_L < dist_vert_R
                stimmen_links_kuerzer = stimmen_links_kuerzer + 1;
            end
        end

        if stimmen_rechts_kuerzer > stimmen_links_kuerzer
            typ = 1;
        elseif stimmen_links_kuerzer > stimmen_rechts_kuerzer
            typ = 2;
        else
            typ = 0;   % unentschieden, wird in erzwinge_Alternanz aufgelöst
        end
        kanten(end+1) = struct('x', x_edge, 'y', y_edge, 'type', typ); %#ok<AGROW>
    end

    % Von links nach rechts sortieren; äußerste Kanten liegen zu nah am Bildrand
    if ~isempty(kanten)
        [~, sortIdx] = sort([kanten.x]);
        kanten = kanten(sortIdx);
        if length(kanten) >= 3
            kanten = kanten(2:end-1);
        else
            kanten = [];
        end
    end
end

function [y_up, y_down] = senkrechter_Strahl(B, x, y_start, imgH)
    y_up = y_start;
    while y_up > 1 && B(y_up, x) == 1, y_up = y_up - 1; end
    y_down = y_start;
    while y_down < imgH && B(y_down, x) == 1, y_down = y_down + 1; end
end

function profil = band_Profil(B, y_mid, imgW, imgH, cfg)
    % 1, wenn im Band um die Mittellinie mindestens ein schwarzer Pixel liegt
    halb = cfg.detektion.band_halb_px;
    profil = zeros(1, imgW);
    for x = 1:imgW
        y = round(y_mid(x));
        profil(x) = any(B(max(1, y - halb):min(imgH, y + halb), x) == 0);
    end
end

%% --- Schritt 4: Alternanz der Kantentypen -------------------------------

function [kanten, seeds] = erzwinge_Alternanz(kanten, seeds, cfg)
    % Im Taylor-Flow wechseln sich Typ 1 und 2 ab. Unentschiedene Kanten
    % erhalten den Gegentyp des Nachbarn; bei zwei gleichen Typen
    % nebeneinander wird die Kante gelöscht, deren Entfernen den typischen
    % Abstandsrhythmus (Median 1->2 bzw. 2->1) besser herstellt.
    if isempty(kanten)
        return;
    end
    i = 1;
    while i <= length(kanten)
        if kanten(i).type == 0
            if i > 1
                kanten(i).type = 3 - kanten(i-1).type;
            elseif i < length(kanten) && kanten(i+1).type ~= 0
                kanten(i).type = 3 - kanten(i+1).type;
            else
                kanten(i).type = 1;
            end
            seeds.tie_cx(end+1) = kanten(i).x;
            seeds.tie_cy(end+1) = kanten(i).y;
        end

        if i < length(kanten) && kanten(i).type == kanten(i+1).type
            [med_1_2, med_2_1] = typische_Abstaende(kanten, cfg.detektion.abstand_ersatz_px);
            typ = kanten(i).type;
            fehler_ohne_i = 0;
            fehler_ohne_naechste = 0;
            if i > 1
                if typ == 1, soll = med_2_1; else, soll = med_1_2; end
                fehler_ohne_i = fehler_ohne_i + abs((kanten(i+1).x - kanten(i-1).x) - soll);
                fehler_ohne_naechste = fehler_ohne_naechste + abs((kanten(i).x - kanten(i-1).x) - soll);
            end
            if i+2 <= length(kanten)
                if typ == 1, soll = med_1_2; else, soll = med_2_1; end
                fehler_ohne_i = fehler_ohne_i + abs((kanten(i+2).x - kanten(i+1).x) - soll);
                fehler_ohne_naechste = fehler_ohne_naechste + abs((kanten(i+2).x - kanten(i).x) - soll);
            end
            if fehler_ohne_i < fehler_ohne_naechste
                weg = i;
            else
                weg = i + 1;
            end
            seeds.tie_cx(end+1) = kanten(weg).x;
            seeds.tie_cy(end+1) = kanten(weg).y;
            kanten(weg) = [];
            % i nicht erhöhen: die nachgerückte Kante erneut prüfen
        else
            i = i + 1;
        end
    end

    for k = 1:length(kanten)
        if kanten(k).type == 1
            seeds.bub_cx(end+1) = kanten(k).x;
            seeds.bub_cy(end+1) = kanten(k).y;
        elseif kanten(k).type == 2
            seeds.slug_cx(end+1) = kanten(k).x;
            seeds.slug_cy(end+1) = kanten(k).y;
        end
    end
end

function [med_1_2, med_2_1] = typische_Abstaende(kanten, ersatz)
    d12 = [];
    d21 = [];
    for k = 1:(length(kanten)-1)
        if kanten(k).type == 1 && kanten(k+1).type == 2
            d12(end+1) = kanten(k+1).x - kanten(k).x; %#ok<AGROW>
        elseif kanten(k).type == 2 && kanten(k+1).type == 1
            d21(end+1) = kanten(k+1).x - kanten(k).x; %#ok<AGROW>
        end
    end
    if isempty(d12), med_1_2 = ersatz; else, med_1_2 = median(d12); end
    if isempty(d21), med_2_1 = ersatz; else, med_2_1 = median(d21); end
end

%% --- Schritt 5: Region Growing ------------------------------------------

function [B_nachher, seeds] = fuelle_Blasen(B_vorher, B_clean, y_mid, ~, seeds, imgW, cfg)
    % Saat rechts neben jeder Blasenkante und links neben jeder Slugkante;
    % die Kantenspalten selbst sperren das Wachstum in x-Richtung.
    Marker = false(size(B_vorher));
    weiss = @(x) B_clean(round(y_mid(x)), x);
    for i = 1:length(seeds.bub_cx)
        x_seed = seeds.bub_cx(i);
        while x_seed < imgW && weiss(x_seed) == 0
            x_seed = x_seed + 1;
        end
        if x_seed < imgW
            Marker(round(y_mid(x_seed)), x_seed) = true;
        end
    end
    for i = 1:length(seeds.slug_cx)
        x_seed = seeds.slug_cx(i);
        while x_seed > 1 && weiss(x_seed) == 0
            x_seed = x_seed - 1;
        end
        if x_seed > 1
            Marker(round(y_mid(x_seed)), x_seed) = true;
        end
    end

    Mask = B_vorher;
    for i = 1:length(seeds.bub_cx)
        Mask(:, seeds.bub_cx(i)) = false;
    end
    for i = 1:length(seeds.slug_cx)
        Mask(:, seeds.slug_cx(i)) = false;
    end

    gefuellt = imreconstruct(Marker, Mask);
    B_nachher = B_vorher & ~gefuellt;
    B_nachher = bwareaopen(B_nachher, cfg.detektion.min_slug_px);

    seeds.Marker = Marker;
    seeds.Mask = Mask;
end

%% --- Schritt 6: Kanalhöhe, Blasen, Unit-Cells ---------------------------

function [kanal, weiter] = schaetze_Kanalhoehe(B, kanal, cfg)
    % Mindestens zwei Slugs sind für eine Unit-Cell nötig. Ist die
    % Kanalhöhe noch nicht aus dem Kanalmodell bekannt, wird sie aus den
    % größeren Bounding-Boxen geschätzt.
    weiter = false;
    [L, num] = bwlabel(B);
    if num < 2
        return;
    end
    stats = regionprops(L, 'Area', 'BoundingBox', 'Solidity', 'Eccentricity', 'Orientation');
    kandidaten = find([stats.Area] > cfg.detektion.min_flaeche_px);
    if isempty(kandidaten)
        return;
    end
    if isnan(kanal.heightEstimate)
        bb = [stats(kandidaten).BoundingBox];
        hoehen = bb(4:4:end);
        if length(hoehen) >= 4
            sortiert = sort(hoehen);
            kanal.heightEstimate = median(sortiert(ceil(end/2):end));
        else
            warning('Kanalhöhe konnte nicht zuverlässig bestimmt werden (zu wenig Objekte). Setze auf NaN.');
            kanal.heightEstimate = NaN;
            return;
        end
    end
    weiter = true;
end

function [det, seeds] = blasen_auf_Mittellinie(B, y_mid, seeds, imgW, imgH, cfg)
    det = struct('cx', {}, 'leftX', {}, 'leftY', {}, 'rightX', {}, 'rightY', {}, 'bb', {});
    [L_bubbles, num_bubbles] = bwlabel(band_Profil(B, y_mid, imgW, imgH, cfg));
    for i = 1:num_bubbles
        xs = find(L_bubbles == i);
        if length(xs) <= cfg.detektion.min_blase_px
            continue;
        end
        leftX = min(xs);
        rightX = max(xs);
        if leftX <= 1 || rightX >= imgW
            continue;   % Blase berührt den Bildrand
        end
        cx = (leftX + rightX) / 2;
        seeds.center_cx(end+1) = cx;
        seeds.center_cy(end+1) = round(y_mid(round(cx)));
        det(end+1) = struct('cx', cx, 'leftX', leftX, 'leftY', round(y_mid(leftX)), ...
            'rightX', rightX, 'rightY', round(y_mid(rightX)), 'bb', [leftX, 1, rightX - leftX, imgH]); %#ok<AGROW>
    end
    % Von rechts nach links sortieren (Strömungsrichtung)
    if ~isempty(det)
        [~, sIdx] = sort([det.cx], 'descend');
        det = det(sIdx);
    end
end

function det = verbinde_Fragmente(det, cfg)
    % Reflexionen können eine Blase in Fragmente teilen; dazwischen liegt
    % dann ein scheinbarer, sehr kurzer Slug. Die typische Slug-Länge ist
    % der Median der am stärksten besetzten Klasse eines Histogramms
    % (cfg.detektion.fragment_klassen Klassen). Slugs kürzer als
    % cfg.detektion.fragment_schwelle_rel mal diese Länge gelten als
    % Reflexion: die beiden angrenzenden Fragmente werden verbunden.
    if numel(det) < 3
        return;
    end
    slugs = [];
    for j = 1:(numel(det)-1)
        len = det(j).leftX - det(j+1).rightX;
        if len > 0
            slugs(end+1) = len; %#ok<AGROW>
        end
    end
    if numel(slugs) < cfg.detektion.fragment_min_slugs
        return;
    end
    slugs = sort(slugs);
    kanten = linspace(min(slugs), max(slugs), cfg.detektion.fragment_klassen + 1);
    [anzahl, ~, klasse] = histcounts(slugs, kanten);
    [~, haeufigste] = max(anzahl);
    schwelle = cfg.detektion.fragment_schwelle_rel * median(slugs(klasse == haeufigste));

    % Von links nach rechts prüfen; nach dem Verbinden dieselbe Stelle erneut
    j = numel(det) - 1;
    while j >= 1
        len = det(j).leftX - det(j+1).rightX;
        if len > 0 && len < schwelle
            % Fragment j+1 (links) übernimmt die rechte Kante von Fragment j
            det(j+1).rightX = det(j).rightX;
            det(j+1).rightY = det(j).rightY;
            det(j+1).cx = (det(j+1).leftX + det(j+1).rightX) / 2;
            det(j+1).bb(3) = det(j+1).rightX - det(j+1).leftX;
            det(j) = [];
            if j > numel(det) - 1
                j = numel(det) - 1;
            end
        else
            j = j - 1;
        end
    end
end

function [blasen, uc_px] = unit_cells(det, imgW, cfg)
    % Unit-Cell j: linke Kante Blase j bis linke Kante Blase j+1.
    % Hinweis (Befund F02): Position = Mitte von Blase j, Länge = Blase j+1.
    blasen = [];
    uc_px = [];
    rand = cfg.detektion.randabstand_px;
    for j = 1:(numel(det)-1)
        bbL = det(j).bb;
        bbR = det(j+1).bb;
        if bbL(1) <= rand || (bbR(1) + bbR(3)) >= (imgW - rand)
            continue;
        end
        uc_len_px = abs(det(j).leftX - det(j+1).leftX);
        blasen_len_px = det(j+1).rightX - det(j+1).leftX;
        if blasen_len_px > 0 && uc_len_px > blasen_len_px
            blasen = [blasen; det(j).cx, blasen_len_px, uc_len_px]; %#ok<AGROW>
            uc_px = [uc_px; uc_len_px]; %#ok<AGROW>
        end
    end
end
