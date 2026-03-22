function updateProgress(~)
% UPDATEPROGRESS Hilfsfunktion für den Konsolen-Fortschritt bei parfor
    persistent pCounter;
    persistent lastRunID;
    
    % Aktuelle Run-ID aus dem Haupt-Workspace holen
    try
        currentRunID = evalin('base', 'batchRunID');
    catch
        currentRunID = 1;
    end
    
    % Wenn sich die Run-ID geändert hat (oder noch leer ist), setze den Zähler zurück
    if isempty(lastRunID) || lastRunID ~= currentRunID
        lastRunID = currentRunID;
        pCounter = 1;
    else
        pCounter = pCounter + 1;
    end
    
    % Holt sich die Gesamtanzahl der Videos aus dem Base-Workspace
    try
        total = evalin('base', 'length(videoFiles)');
        fprintf('Fortschritt: %d / %d Videos abgeschlossen...\n', pCounter, total);
    catch
        fprintf('Ein weiteres Video abgeschlossen (%d Gesamt).\n', pCounter);
    end
end
