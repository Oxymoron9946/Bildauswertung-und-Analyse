function [bubbleTracker, prevBubbleCentroids, nextBubbleID] = track_Bubbles(currentBubbleCentroids, prevBubbleCentroids, bubbleTracker, nextBubbleID, frameIdx, maxJumpDist_px)
% TRACK_BUBBLES Verfolgt Blasen ueber Frames hinweg und ordnet ihnen IDs zu.
%
% Eingaben:
%   currentBubbleCentroids - [N x 2] Matrix [X_Koordinate, Laenge_px] im aktuellen Frame
%   prevBubbleCentroids    - [M x 2] Matrix [ID, X_Koordinate] aus dem letzten Frame
%   bubbleTracker          - Gesamt-Speicher-Matrix fuer das Tracking-Protokoll
%   nextBubbleID           - Laufende Nummer fuer die naechste neue Blase
%   frameIdx               - Aktueller Frame-Index (Zeitstempel)
%   maxJumpDist_px         - Maximal erlaubter X-Sprung einer Blase pro Frame
%
% Rueckgaben:
%   bubbleTracker          - Aktualisiertes Tracking-Protokoll (ID, Frame, X, Laenge)
%   prevBubbleCentroids    - Aktualisierte Liste fuer den Abgleich im naechsten Frame
%   nextBubbleID           - Aktualisierte Zaehlervariable fuer neue Blasen

    %% 1. Initialisierung
    newPrevBubbleCentroids = [];

    % Wenn in diesem Frame keine Blasen gefunden wurden, Tracking hier abbrechen
    if isempty(currentBubbleCentroids)
        prevBubbleCentroids = []; % Historie loeschen, da Abriss im Tracking
        return; 
    end

    %% 2. Zuweisungsschleife ueber alle aktuellen Blasen
    for c = 1:size(currentBubbleCentroids, 1)
        currX = currentBubbleCentroids(c, 1);
        currLen = currentBubbleCentroids(c, 2);
        currUC = currentBubbleCentroids(c, 3); % NEU: Unit-Cell Länge auslesen
        assignedID = -1;

        %% 2.1 Abgleich mit bekannten Blasen aus dem vorherigen Frame
        if ~isempty(prevBubbleCentroids)
            % Abstaende zwischen alten Positionen und aktueller Position berechnen
            % (Stromrichtung von rechts nach links, daher erwarten wir, dass currX kleiner wird)
            x_diffs = prevBubbleCentroids(:, 2) - currX;

            % Gueltige Uebereinstimmungen: 
            % - Blase hat sich leicht nach rechts bewegt (Rauschen, diff >= -2)
            % - Blase hat sich nach links bewegt, aber nicht weiter als maxJumpDist_px
            validMatches = find(x_diffs >= -2 & x_diffs < maxJumpDist_px);

            if ~isempty(validMatches)
                % Den naechstgelegenen alten Zentroid als Match waehlen
                [~, bestMatchIdx] = min(x_diffs(validMatches));
                bestOldIdx        = validMatches(bestMatchIdx);

                % ID uebernehmen und genutzte Blase aus der Liste entfernen
                assignedID        = prevBubbleCentroids(bestOldIdx, 1);
                prevBubbleCentroids(bestOldIdx, :) = []; 
            end
        end

        %% 2.2 Neue ID vergeben, falls kein Match gefunden
        if assignedID == -1
            assignedID   = nextBubbleID;
            nextBubbleID = nextBubbleID + 1;
        end

        %% 2.3 Ergebnisse des aktuellen Frames protokollieren
        % Format: [BubbleID, FrameIndex, PositionX_px, Bubble_Laenge_px, UC_Laenge_px]
        bubbleTracker = [bubbleTracker; assignedID, frameIdx, currX, currLen, currUC]; %#ok


        % Uebergabe an den naechsten Frame vorbereiten [ID, PositionX]
        newPrevBubbleCentroids = [newPrevBubbleCentroids; assignedID, currX]; %#ok<AGROW>
    end

    %% 3. Abschluss
    % Die alten (nicht zugewiesenen) Zentroide verfallen hiermit
    prevBubbleCentroids = newPrevBubbleCentroids;
end
