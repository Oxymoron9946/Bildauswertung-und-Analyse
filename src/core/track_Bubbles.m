function [bubbleTracker, prevBubbleCentroids, nextBubbleID] = track_Bubbles(currentBubbleCentroids, prevBubbleCentroids, bubbleTracker, nextBubbleID, frameIdx, maxJumpDist_px)
% TRACK_BUBBLES Verfolgt Blasen über aufeinanderfolgende Frames hinweg und ordnet ihnen IDs zu.
%
% Diese Funktion nimmt die aktuell gefundenen Blasen (aus detect_Bubbles) und 
% vergleicht ihre Position mit den Blasen aus dem vorherigen Frame. 
% So entsteht ein durchgehendes Tracking-Protokoll, aus dem später 
% die Geschwindigkeit (Weg pro Zeit) berechnet werden kann.
%
% EINGABEN:
%   currentBubbleCentroids - [N x 3] Matrix: [Start_X_der_UC, Blasenlaenge_px, UC_Laenge_px]
%   prevBubbleCentroids    - [M x 2] Matrix: [Bubble_ID, Start_X_der_UC] aus dem letzten Frame
%   bubbleTracker          - Gesamt-Speichermatrix (Protokoll) über das gesamte Video
%   nextBubbleID           - Fortlaufende Nummer für neu ins Bild fliegende Blasen
%   frameIdx               - Aktuelle Bildnummer (dient als Zeitstempel)
%   maxJumpDist_px         - Maximaler X-Sprung, den eine Blase pro Frame machen darf
%
% RÜCKGABEN:
%   bubbleTracker          - Aktualisiertes Protokoll inkl. dieses Frames
%   prevBubbleCentroids    - Zentroide dieses Frames (für den Abgleich im nächsten Frame)
%   nextBubbleID           - Aktualisierte Zählervariable
%
% BATCH / EINZEL (main_Batch.m, main_einzel.m):
%   Wird pro Frame nach detect_Bubbles aufgerufen; bubbleTracker sammelt Zeilen
%   [ID, Frame, X_Start_UC_px, BubbleLen_px, UC_Len_px] für evaluate_Physics.
%   Strömung rechts → links (höhere X: ältere Position); maxJumpDist_px aus params.

    %% 1. Initialisierung & Sicherheitsabbruch
    newPrevBubbleCentroids = [];
    
    % Wenn in diesem Frame (z.B. durch Unschärfe oder Bildfehler) absolut 
    % keine Blasen detektiert wurden, brechen wir das Tracking für diesen Frame ab.
    if isempty(currentBubbleCentroids)
        % Wir löschen die Historie. Warum? Wenn im nächsten Frame wieder 
        % Blasen auftauchen, wissen wir nicht sicher, welche welche ist.
        % Ein sauberer Neustart der IDs ist sicherer für die Statistik!
        prevBubbleCentroids = []; 
        return; 
    end
    
    %% 2. Zuweisungsschleife über alle aktuell gefundenen Blasen
    for c = 1:size(currentBubbleCentroids, 1)
        
        % Daten der aktuellen Blase aus der Matrix auslesen
        currX   = currentBubbleCentroids(c, 1); % X-Position (Start der Unit-Cell)
        currLen = currentBubbleCentroids(c, 2); % Länge der Blase
        currUC  = currentBubbleCentroids(c, 3); % Länge der gesamten Unit-Cell
        
        assignedID = -1; % Startwert: Noch keine ID zugewiesen
        
        %% 2.1 Abgleich mit bekannten Blasen aus dem vorherigen Frame
        if ~isempty(prevBubbleCentroids)
            
            % Wir vergleichen die alte X-Position mit der neuen X-Position.
            % WICHTIG: Die Strömung läuft von rechts (hohe Pixelzahl) 
            % nach links (niedrige Pixelzahl).
            % Alte X - Neue X = Ein positiver Wert, wenn die Blase nach links gewandert ist!
            x_diffs = prevBubbleCentroids(:, 2) - currX;
            
            % Was gilt als "plausibler" Sprung?
            % 1. Die Blase darf nicht (oder nur durch Rauschen minimal: -2px) "rückwärts" fließen.
            % 2. Die Blase darf nicht schneller sein als unsere maxJumpDist_px.
            validMatches = find(x_diffs >= -2 & x_diffs < maxJumpDist_px);
            
            if ~isempty(validMatches)
                % Wenn es mehrere Kandidaten gibt (was bei dichtem Flow passieren kann),
                % nehmen wir die Blase, die die KLEINSTE Distanz zurückgelegt hat
                % (Das ist physikalisch am wahrscheinlichsten).
                [~, bestMatchIdx] = min(x_diffs(validMatches));
                bestOldIdx        = validMatches(bestMatchIdx);
                
                % ID der alten Blase übernehmen (Tracking erfolgreich!)
                assignedID        = prevBubbleCentroids(bestOldIdx, 1);
                
                % Diese alte Blase aus der Liste entfernen, damit sie nicht
                % versehentlich einer zweiten neuen Blase zugewiesen wird.
                prevBubbleCentroids(bestOldIdx, :) = []; 
            end
        end
        
        %% 2.2 Neue ID vergeben, falls kein Match gefunden wurde
        % Wenn assignedID immer noch -1 ist, bedeutet das: Diese Blase ist 
        % frisch von rechts ins Bild geflogen (oder das Tracking ist vorher abgerissen).
        if assignedID == -1
            assignedID   = nextBubbleID;     % Gib ihr die nächste freie Nummer
            nextBubbleID = nextBubbleID + 1; % Zähler für die Zukunft erhöhen
        end
        
        %% 2.3 Ergebnisse des aktuellen Frames protokollieren
        % Hänge diese Blase an das große Video-Protokoll an.
        % Spalten: [BubbleID, FrameIndex, PositionX_px, Bubble_Laenge_px, UC_Laenge_px]
        bubbleTracker = [bubbleTracker; assignedID, frameIdx, currX, currLen, currUC]; %#ok<AGROW>
        
        % Übergabe an den NÄCHSTEN Frame vorbereiten
        % Wir speichern nur ID und X-Position, das reicht für den nächsten Distanz-Check
        newPrevBubbleCentroids = [newPrevBubbleCentroids; assignedID, currX]; %#ok<AGROW>
    end
    
    %% 3. Abschluss des aktuellen Frames
    % Alle alten Blasen, die jetzt noch in "prevBubbleCentroids" stehen, 
    % wurden in diesem Frame nicht mehr gefunden (sind links aus dem Bild geflogen).
    % Sie verfallen. Wir überschreiben die Variable mit den soeben neu gefundenen Positionen.
    prevBubbleCentroids = newPrevBubbleCentroids;
end