function m = lies_Messlauf(video)
% LIES_MESSLAUF Liest Messlauf, Kalibriergruppe und Metadaten aus dem Videopfad.
%
% Erwartete Ordnerstruktur:
%   .../Pos_<n>_Kal_<k>/<jG>_<jL>_Pos_<n>_<Form>_<Kanal_um>_<Material>_<Nadel_um>[_Druck]/<fps>fps_<nnn>/<video>.avi
%
% Der Messlauf ist der Schlüssel zum Laborbuch (Spalte "Dateiname"). Liegt
% das Video in einem Aufnahmeordner "<fps>fps_<nnn>", ist der Messlauf der
% übergeordnete Ordner.
%
% Parameter
% ---------
% video : Pfad zum Messvideo
%
% Rückgabe
% --------
% m : struct mit
%     name        Messlauf (Ordnername)
%     aufnahme    Aufnahmeordner "<fps>fps_<nnn>" ("" wenn das Video direkt im Messlauf liegt);
%                 mehrere Aufnahmen desselben Messlaufs unterscheiden sich nur hier
%     gruppe      Kalibriergruppe "Pos_<n>_Kal_<k>" ('' wenn nicht im Pfad)
%     messart     "Druckkalibrierung" oder "Massentransfer"
%     schema      true, wenn der Ordnername dem Schema entspricht
%     gas, liq    Leerrohrgeschwindigkeiten als Text [m/s] ("NaN" ohne Schema)
%     pos         Kameraposition
%     form, material  Text ("NaN" ohne Schema)
%     kanal, nadel    Text [µm] ("NaN" ohne Schema)

    [ordner, ~, ~] = fileparts(video);
    [eltern, aktuell, endung] = fileparts(ordner);
    aktuell = strcat(aktuell, endung);   % Punkte im Ordnernamen sind keine Endung
    if contains(aktuell, 'fps', 'IgnoreCase', true)
        [~, n, e] = fileparts(eltern);
        m.name = strcat(n, e);
        m.aufnahme = string(aktuell);
    else
        m.name = aktuell;
        m.aufnahme = "";
    end

    tok = regexp(video, '(Pos_\d+_Kal_\d+)', 'tokens');
    if isempty(tok)
        m.gruppe = '';
    else
        m.gruppe = tok{1}{1};
    end

    m.messart = messart(m.name);

    t = regexp(m.name, ['(?<gas>[\d\.]+)_(?<liq>[\d\.]+)_Pos_(?<pos>\d+)_(?<form>[A-Za-z]+)_' ...
        '(?<kanal>\d+)_(?<mat>[A-Za-z]+)_(?<nadel>\d+)'], 'names');
    m.schema = ~isempty(t);
    if m.schema
        m.gas = string(t.gas);
        m.liq = string(t.liq);
        m.pos = str2double(t.pos);
        m.form = string(t.form);
        m.kanal = string(t.kanal);
        m.material = string(t.mat);
        m.nadel = string(t.nadel);
    else
        m.gas = "NaN"; m.liq = "NaN"; m.pos = NaN;
        m.form = "NaN"; m.kanal = "NaN"; m.material = "NaN"; m.nadel = "NaN";
    end
end

function art = messart(name)
    % Druckkalibrierungen tragen "Druck" im Ordnernamen.
    if contains(name, 'Druck', 'IgnoreCase', true)
        art = "Druckkalibrierung";
    else
        art = "Massentransfer";
    end
end
