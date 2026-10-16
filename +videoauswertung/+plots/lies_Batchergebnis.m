function tab = lies_Batchergebnis(dateien)
% LIES_BATCHERGEBNIS Liest eine oder mehrere Batch-Ergebnisdateien (Semikolon).
%
% Geschwindigkeiten und Textspalten werden als Text gelesen, damit z. B.
% "0.07" exakt so bleibt, wie es im Ordnernamen steht.
%
% Parameter
% ---------
% dateien : Pfad oder cellstr von Pfaden
%
% Rückgabe
% --------
% tab : table, alle Dateien untereinander

    dateien = cellstr(dateien);
    teile = cell(numel(dateien), 1);
    for k = 1:numel(dateien)
        opts = detectImportOptions(dateien{k}, 'Delimiter', ';', 'VariableNamingRule', 'preserve');
        text = intersect({'GasVelocity', 'LiquidVelocity', 'Material', 'Geometrie', 'Messart', 'Aufnahme'}, ...
            opts.VariableNames);
        opts = setvartype(opts, text, 'string');
        teile{k} = readtable(dateien{k}, opts);
    end
    tab = vertcat(teile{:});
end
