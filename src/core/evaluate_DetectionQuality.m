function [isGood, reason] = evaluate_DetectionQuality(statsTable)
    % evaluate_DetectionQuality bewertet die Qualität der Blasen-Detektion.
    % Gibt true zurück, wenn die Werte physikalisch plausibel sind (Slug-Flow).
    %
    % BATCH (main_Batch.m): Aufruf nach evaluate_Physics — am Ende jedes
    % Sensitivitätsdurchlaufs und in der Early-Abort-Stichprobe (Block 4/5).
    % Ausgabe reason wird im Batch nicht ausgewertet (nur Diagnose bei Bedarf).
    %
    % HEURISTIK (LaTeX/Methode: Kurz beschreiben, Zahlen optional im Anhang):
    %   (1) Mindestens minDataPoints Zeilen in statsTable (harte Untergrenze).
    %   (2) Falls eine Spalte mit „Length“/„Laenge“ existiert: CoV = std/mean der Längen ≤ 0.07.
    %   (3) Falls eine Spalte mit „Velocity“/„Geschwindigkeit“ existiert: CoV ≤ 0.15.
    %   Alle drei erfüllt → isGood true (Slug-Flow plausibel genug für den Batch).
    
    % 1. Wurden überhaupt genug Blasen/Datenpunkte gefunden?
    minDataPoints = 5; % Mindestens 5 auswertbare Blasen/Bins
    if height(statsTable) < minDataPoints
        isGood = false;
        reason = sprintf('Zu wenige Datenpunkte (%d < %d)', height(statsTable), minDataPoints);
        return;
    end
    
    % --- Spaltennamen dynamisch finden ---
    colNames = statsTable.Properties.VariableNames;
    
    lenCol = colNames(contains(colNames, 'Length', 'IgnoreCase', true) | contains(colNames, 'Laenge', 'IgnoreCase', true));
    velCol = colNames(contains(colNames, 'Velocity', 'IgnoreCase', true) | contains(colNames, 'Geschwindigkeit', 'IgnoreCase', true));
    
    % 2. Längen-Varianz und absolute Standardabweichung prüfen
    if ~isempty(lenCol)
        laengen = statsTable.(lenCol{1});
        meanLen = mean(laengen, 'omitnan');
        stdLen  = std(laengen, 'omitnan');
        
        % CoV (Coefficient of Variation) = Standardabweichung / Mittelwert
        covLen = stdLen / meanLen;
        
        if covLen > 0.07 
            isGood = false;
            reason = sprintf('Laengen-Varianz zu hoch (CoV = %.2f)', covLen);
            return;
        end
    end
    
    % 3. Geschwindigkeits-Varianz und absolute Standardabweichung prüfen
    if ~isempty(velCol)
        geschw = statsTable.(velCol{1});
        meanVel = mean(geschw, 'omitnan');
        stdVel  = std(geschw, 'omitnan');
        
        % CoV für relative Abweichung
        covVel = stdVel / meanVel;
        
        if covVel > 0.15
            isGood = false;
            reason = sprintf('Geschwindigkeits-Varianz zu hoch (CoV = %.2f)', covVel);
            return;
        end
    end
    
    % Wenn alle Tests bestanden sind:
    isGood = true;
    reason = 'Qualitaet OK';
end