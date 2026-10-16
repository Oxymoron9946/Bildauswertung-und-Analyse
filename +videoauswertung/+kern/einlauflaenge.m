function L_ein_mm = einlauflaenge(m, cfg)
% EINLAUFLAENGE Hydrodynamische Einlauflänge L_ein = faktor · Re · d_h.
%
%   Re = rho · (j_G + j_L) · d_h / mu
%
% mit den Stoffwerten der kontinuierlichen Phase aus cfg.einlauf und dem
% hydraulischen Durchmesser d_h = Kanalmaß aus dem Ordnernamen.
%
% Parameter
% ---------
% m : struct aus lies_Messlauf (gas, liq [m/s], kanal [µm])
% cfg : struct aus config()
%
% Rückgabe
% --------
% L_ein_mm : Einlauflänge [mm]; NaN, wenn der Ordnername dem Schema nicht entspricht

    j_G = str2double(m.gas);
    j_L = str2double(m.liq);
    d_h_mm = str2double(m.kanal) / 1000;
    if isnan(j_G) || isnan(j_L) || isnan(d_h_mm)
        L_ein_mm = NaN;
        return;
    end
    Re = (cfg.einlauf.rho_kg_m3 * (j_G + j_L) * (d_h_mm / 1000)) / cfg.einlauf.mu_Pa_s;
    L_ein_mm = cfg.einlauf.faktor * Re * d_h_mm;
end
