function [currentBubbleCentroids, channelHeightEstimate, det, currentUC_px] = detect_Bubbles(I, channelHeightEstimate, params)
    [imgH, imgW] = size(I);
    currentBubbleCentroids = [];
    currentUC_px = []; % Speichert die Unit Cells dieses Frames
    
    I_eq = adapthisteq(I, 'NumTiles', [4 8], 'ClipLimit', 0.01);
    B = imbinarize(I_eq, graythresh(I_eq));
    B = imfill(B, 'holes');
    B = bwareaopen(B, params.minPixel);
    
    [L, num] = bwlabel(B);
    if num < 2, det = []; return; end
    
    statsBasic = regionprops(L, 'Area', 'BoundingBox');
    candidateIdx = find([statsBasic.Area] > params.minArea);
    if isempty(candidateIdx), det = []; return; end
    
    if isnan(channelHeightEstimate)
        candidateHeights = [statsBasic(candidateIdx).BoundingBox];
        candidateHeights = candidateHeights(4:4:end);
        if length(candidateHeights) >= 4
            sortedH = sort(candidateHeights);
            channelHeightEstimate = median(sortedH(ceil(end/2):end));
        else
            channelHeightEstimate = imgH * 0.4; 
        end
    end
    
    statsFull = regionprops(L, 'Solidity', 'Eccentricity', 'Orientation', 'Centroid');
    
    det = struct('cx',{},'leftX',{},'leftY',{},'rightX',{},'rightY',{},'bb',{});
    for k = candidateIdx
        bb = statsBasic(k).BoundingBox;
        if bb(4) < 0.80 * channelHeightEstimate, continue; end
        if abs(statsFull(k).Centroid(2) - imgH/2) > (imgH * 0.40), continue; end
        
        sol = statsFull(k).Solidity; ecc = statsFull(k).Eccentricity; ori = statsFull(k).Orientation;
        if ~(sol >= params.minSolid && sol <= params.maxSolid && ecc >= params.minEcc && abs(ori) >= params.minAngle), continue; end
        
        bx0 = max(1, floor(bb(1))); by0 = max(1, floor(bb(2)));
        bx1 = min(imgW, ceil(bb(1)+bb(3)-1)); by1 = min(imgH, ceil(bb(2)+bb(4)-1));
        if bx1 <= bx0 || by1 <= by0, continue; end
        
        subL = L(by0:by1, bx0:bx1);
        [rP, cP] = find(bwperim(subL == k, 8));
        if isempty(rP), continue; end
        
        cx_local = statsFull(k).Centroid(1) - bx0 + 1;
        spanY = max(rP) - min(rP); midY = (min(rP)+max(rP))/2;
        
        inBand = (rP >= midY - spanY*params.toleranceY) & (rP <= midY + spanY*params.toleranceY);
        cBand = cP(inBand); rBand = rP(inBand);
        if isempty(cBand), continue; end
        
        leftMask = cBand < cx_local; rightMask = cBand >= cx_local;
        if ~any(leftMask) || ~any(rightMask), continue; end
        
        left_x_local = max(cBand(leftMask));
        right_x_local = min(cBand(rightMask));
        
        det(end+1) = struct( ...
            'cx', statsFull(k).Centroid(1), ...
            'leftX', left_x_local + bx0 - 1, ...
            'leftY', round(mean(rBand(cBand == left_x_local))) + by0 - 1, ...
            'rightX', right_x_local + bx0 - 1, ...
            'rightY', round(mean(rBand(cBand == right_x_local))) + by0 - 1, ...
            'bb', [bx0 by0 (bx1-bx0+1) (by1-by0+1)]);
    end
    
    if numel(det) < 2, return; end
    
    [~, sIdx] = sort([det.cx], 'descend');
    det = det(sIdx);
    
    for j = 1:(numel(det)-1)
        bbLeft = det(j).bb; bbRight = det(j+1).bb;
        if bbLeft(1) <= params.borderMargin || (bbRight(1) + bbRight(3)) >= (imgW - params.borderMargin), continue; end
        
        x_e = det(j+1).rightX; 
        x_s = det(j).leftX;    
        len_px = x_s - x_e;
        
        if len_px > 0
            mid_x = (x_e + x_s) / 2;
            currentBubbleCentroids = [currentBubbleCentroids; mid_x, len_px]; %#ok<AGROW>
            
            % Unit Cell: Abstand linke Kante Slug j zu linker Kante Slug j+1
            currentUC_px = [currentUC_px; abs(det(j).leftX - det(j+1).leftX)]; %#ok<AGROW>
        end
    end
end
