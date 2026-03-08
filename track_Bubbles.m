function [bubbleTracker, prevBubbleCentroids, nextBubbleID] = track_Bubbles(currentBubbleCentroids, prevBubbleCentroids, bubbleTracker, nextBubbleID, frameIdx, maxJumpDist_px)
    newPrevBubbleCentroids = [];
    if isempty(currentBubbleCentroids), return; end
    
    for c = 1:size(currentBubbleCentroids, 1)
        currX = currentBubbleCentroids(c, 1);
        currLen = currentBubbleCentroids(c, 2);
        assignedID = -1;
        
        if ~isempty(prevBubbleCentroids)
            x_diffs = prevBubbleCentroids(:, 2) - currX;
            validMatches = find(x_diffs >= -2 & x_diffs < maxJumpDist_px);
            if ~isempty(validMatches)
                [~, bestMatchIdx] = min(x_diffs(validMatches));
                bestOldIdx = validMatches(bestMatchIdx);
                assignedID = prevBubbleCentroids(bestOldIdx, 1);
                prevBubbleCentroids(bestOldIdx, :) = []; % Verwendete löschen
            end
        end
        
        if assignedID == -1
            assignedID = nextBubbleID;
            nextBubbleID = nextBubbleID + 1;
        end
        
        % NEU: Jeden Frame als neuen Datenpunkt speichern!
        % Spalten: [ID, frameIdx, X_px, Len_px]
        bubbleTracker = [bubbleTracker; assignedID, frameIdx, currX, currLen]; %#ok<AGROW>
        
        newPrevBubbleCentroids = [newPrevBubbleCentroids; assignedID, currX]; %#ok<AGROW>
    end
    prevBubbleCentroids = newPrevBubbleCentroids;
end
