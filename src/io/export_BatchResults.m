function export_BatchResults(statsCell, outputBaseDir)
% EXPORT_BATCHRESULTS Fügt die Ergebnisse der parfor-Schleife zusammen und speichert sie als CSV.

    validStatsIdx = cellfun(@(x) ~isempty(x) && istable(x) && height(x) > 0, statsCell);
    statsCell = statsCell(validStatsIdx);

    if isempty(statsCell)
        fprintf('Keine validen Daten zur Speicherung gefunden.\n');
        return;
    end

    % Alle einzelnen Video-Tabellen untereinanderhängen
    MasterTableStats = vertcat(statsCell{:});
    
    % Nach Spalte Messart splitten
    messarten = unique(MasterTableStats.Messart);
    
    for m = 1:length(messarten)
        aktuelleMessart = string(messarten(m));
        teilTabelle = MasterTableStats(string(MasterTableStats.Messart) == aktuelleMessart, :);
        
        outMat   = teilTabelle.Material(1);
        outForm  = teilTabelle.Geometrie(1);
        outKanal = num2str(teilTabelle.Kanal_um(1));
        outLen   = num2str(teilTabelle.Reaktor_cm(1));
        outNadel = num2str(teilTabelle.Nadel_um(1));
        outCO2   = num2str(teilTabelle.CO2_Anteil(1) * 100); 
        
        if aktuelleMessart == "Druckkalibrierung"
            outFolder = fullfile(outputBaseDir, 'Ausgabe_Druckkalibrierung');
            prefix = 'Auswertung_Druck';
        else
            outFolder = fullfile(outputBaseDir, 'Ausgabe_Massentransfer');
            prefix = 'Auswertung_Masse';
        end
        
        if ~exist(outFolder, 'dir')
            mkdir(outFolder);
        end
        
        fileName = sprintf('%s_%s_%s_%sum_%scm_%smolCO2_%sum.csv', ...
                            prefix, outMat, outForm, outKanal, outLen, outCO2, outNadel);
        
        savePath = fullfile(outFolder, fileName);
        writetable(teilTabelle, savePath, 'Delimiter', ';');
        fprintf('ERFOLG: %d Zeilen gespeichert in Ordner:\n%s\nDateiname: %s\n', height(teilTabelle), outFolder, fileName);
        
        % --- NEU: Generiere und speichere den Plot ---
        % Wir ersetzen die Endung .csv durch .png
        savePathPNG = strrep(savePath, '.csv', '.png');
        try
            plot_MergedBatchResults(teilTabelle, savePathPNG);
            fprintf('Plot gespeichert unter: %s\n', savePathPNG);
        catch ME
            warning('Fehler beim Plotten für %s: %s', fileName, ME.message);
        end
    end
end
