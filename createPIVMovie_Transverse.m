% createPIVMovie_Transverse.m
% 
% Video visualization showing TRANSVERSE velocity component.
% Matches the transverse analysis version of obtainMotilityParameters.
% 
% Each mesh cell is colored according to its measured TRANSVERSE velocity:
%   - Blue = motion in one transverse direction (e.g., dorsal)
%   - Orange = motion in opposite transverse direction (e.g., ventral)
%   - Intensity = velocity magnitude
%
% Kymograph shows transverse QSTMap (top/bottom difference) with 
% percentile-based scaling.
%
% January 2026

function createPIVMovie(curAnDir, curExpDir, analysisVariables, PIVVideoParams, PIVOutputName, interpolationOutputName)

%% ========== CONFIGURABLE PARAMETERS ==========

% Visualization mode
useDiscreteCells = true;          % Show discrete colored cells (vs smooth field)
cellAlpha = 0.33;                  % Transparency of colored cells (0-1)

% Color settings - for TRANSVERSE motion
contractColor = [1.0 0.5 0.1];    % Orange for contraction direction
expandColor = [0.1 0.5 1.0];      % Blue for expansion direction
maxVelocityForColor = 0;          % Max velocity for color scaling (0 = auto)

% Mesh grid overlay
showMeshGrid = true;               % Overlay the mesh grid lines
meshGridColor = [0.3 1.0 0.3];    % Bright green
meshGridLineWidth = 1.0;           % Line thickness
meshGridSpacing = 1;               % Show every Nth grid line
meshGridAlpha = 0.10;               % Transparency (0=invisible, 1=opaque)

% Optional sparse arrows - disabled by default for transverse
% (transverse motion is perpendicular to gut axis, harder to show as arrows)
showArrows = false;               
arrowSpacing = 3;
arrowColor = [1 1 1];
arrowLineWidth = 1.5;
velMultiple = 20;

% Annotations
showTimestamp = true;
showScaleBar = true;
showColorLegend = true;
showKymograph = true;

% Video settings
do_histEq = false;
scaleBarMicrons = 0;

% Kymograph scaling (percentile-based to handle outliers)
usePercentileScaling = true;      % Use percentile-based scaling for kymograph
kymographPercentiles = [1, 99];   % [lower, upper] percentiles

%% ========== LOAD DATA AND SETUP ==========

suffix = analysisVariables{1};
fps = str2double(analysisVariables{3});
origMicronsPerPixel = str2double(analysisVariables{4});
origResReduction = str2double(analysisVariables{5});

startTP = PIVVideoParams(1,1)/100;
deltaF = PIVVideoParams(1,2);
endTP = PIVVideoParams(1,3)/100;
startX = PIVVideoParams(2,1)/100;
resReduceNew = PIVVideoParams(2,2);
endX = PIVVideoParams(2,3)/100;
resReduce = resReduceNew * origResReduction;
micronsPerPixel = origMicronsPerPixel * resReduce;

load(fullfile(curAnDir, [interpolationOutputName '_Current.mat']), ...
    'gutMesh', 'gutMeshVels', 'gutMeshVelsPCoords', 'thetas');

% Load the user-drawn gut mask
maskFileName = 'maskVars_Current.mat';
if exist(fullfile(curAnDir, maskFileName), 'file')
    maskData = load(fullfile(curAnDir, maskFileName), 'gutOutlinePoly');
    gutOutlinePoly = maskData.gutOutlinePoly;
    hasUserMask = true;
    fprintf('  Loaded user-drawn gut mask\n');
else
    hasUserMask = false;
    warning('Gut mask file not found');
end

%% ========== BUILD FILENAME LIST ==========

direc = dir(fullfile(curExpDir, suffix)); 
baseFilenames = {};
[baseFilenames{1:length(direc),1}] = deal(direc.name);
baseFilenames = sortrows(baseFilenames);
amount = length(baseFilenames);
count = 1;
filenames = {};

progbar1 = waitbar(0, 'Obtaining image information...');

if strcmp(suffix, '*.tif')
    for i = 1:amount
        waitbar(i/amount, progbar1);
        info = imfinfo(fullfile(curExpDir, baseFilenames{i}));
        nI = size(info, 1);
        for j = 1:nI
            filenames{count}.name = info.Filename;
            filenames{count}.index = j;
            count = count + 1;
        end
    end
else
    for i = 1:amount
        filenames{i}.name = baseFilenames{i};
        filenames{i}.index = 1;
    end
end
close(progbar1);

%% ========== VIDEO PROPERTIES ==========

nF = size(filenames, 2);
info = imfinfo(fullfile(curExpDir, baseFilenames{1}));
numRows = info(1).Height;
numCols = info(1).Width;

startingFrame = round(nF * startTP + 1);
endingFrame = round(nF * endTP);
startingPosition = round(numCols * startX + 1);
endingPosition = round(numCols * endX);

dispRows = floor(numRows / resReduce);
dispCols = floor((endingPosition - startingPosition + 1) / resReduce);

%% ========== SCALE BAR ==========

if scaleBarMicrons == 0
    imageWidthMicrons = dispCols * micronsPerPixel;
    magnitude = 10^floor(log10(imageWidthMicrons * 0.12));
    scaleBarMicrons = round(imageWidthMicrons * 0.12 / magnitude) * magnitude;
    if scaleBarMicrons == 0, scaleBarMicrons = 50; end
end
scaleBarPixels = scaleBarMicrons / micronsPerPixel;

%% ========== DETERMINE VELOCITY RANGE (TRANSVERSE) ==========

% Use TRANSVERSE component (index 2) from gutMeshVelsPCoords
if maxVelocityForColor == 0
    sampleFrames = round(linspace(1, size(gutMeshVelsPCoords, 4), min(20, size(gutMeshVelsPCoords, 4))));
    allVels = [];
    for sf = sampleFrames
        velFrame = gutMeshVelsPCoords(:,:,2,sf);  % TRANSVERSE component
        allVels = [allVels; velFrame(:)];
    end
    maxVelocityForColor = prctile(abs(allVels), 95);
    fprintf('  Auto-detected TRANSVERSE velocity range: Â±%.2f Âµm/s\n', maxVelocityForColor);
end

%% ========== KYMOGRAPH DATA (TRANSVERSE) ==========

if showKymograph
    % TRANSVERSE: difference between bottom half and top half (contraction formula)
    nMeshRowsForKymo = size(gutMeshVelsPCoords, 1);
    qstMap = 2 * squeeze(mean(gutMeshVelsPCoords(floor(nMeshRowsForKymo/2)+1:end,:,2,:), 1) - ...
                         mean(gutMeshVelsPCoords(1:floor(nMeshRowsForKymo/2),:,2,:), 1))';
    
    scale = origMicronsPerPixel * origResReduction;
    translateMarkerNumToMicron = scale * round(mean(diff(squeeze(gutMesh(1,:,1,1)))));
    qstXAxis = (0:size(qstMap,2)-1) * translateMarkerNumToMicron;
    qstYAxis = (0:size(qstMap,1)-1) / fps;
    
    % Percentile-based scaling for kymograph
    if usePercentileScaling
        kymographMin = prctile(qstMap(:), kymographPercentiles(1));
        kymographMax = prctile(qstMap(:), kymographPercentiles(2));
    else
        kymographMin = min(qstMap(:));
        kymographMax = max(qstMap(:));
    end
    fprintf('  Kymograph (TRANSVERSE) velocity range: %.2f to %.2f\n', kymographMin, kymographMax);
end

%% ========== HISTOGRAM EQ PREP ==========

if do_histEq
    firstIm = imreadSubsampled(fullfile(filenames{1}.name), [1 resReduce numRows], [startingPosition resReduce endingPosition], 'Index', filenames{1}.index);
    firstImHistExample = histeq(firstIm);
    maxI = double(max(firstImHistExample(:)));
    minI = double(min(firstImHistExample(:)));
end

%% ========== SETUP VIDEO WRITER ==========

writerObj = VideoWriter(fullfile(curAnDir, PIVOutputName), 'Uncompressed AVI');
open(writerObj);

%% ========== CREATE FIGURE ==========

if showKymograph
    figWidth = 1200;
    figHeight = 500;
else
    figWidth = 900;
    figHeight = 600;
end

fig = figure('Position', [100 100 figWidth figHeight], ...
    'Visible', 'on', 'Resize', 'off', ...
    'MenuBar', 'none', 'ToolBar', 'none');
set(fig, 'Renderer', 'painters', 'Color', [0.15 0.15 0.15]);
drawnow;

%% ========== CREATE MAIN AXES ==========

if showKymograph
    ax_main = axes('Position', [0.01 0.06 0.65 0.92]);
else
    ax_main = axes('Position', [0.03 0.05 0.90 0.92]);
end

% Read first frame
firstImage = imreadSubsampled(fullfile(filenames{startingFrame}.name), ...
    [1 resReduce numRows], [startingPosition resReduce endingPosition], ...
    'Index', filenames{startingFrame}.index);
if do_histEq
    firstImage = (double(imhistmatch(firstImage, firstImHistExample)) - minI) / (maxI - minI);
else
    firstImage = double(firstImage);
end

firstImageNorm = (firstImage - min(firstImage(:))) / (max(firstImage(:)) - min(firstImage(:)));
hImg = imshow(firstImageNorm, []);
set(ax_main, 'YDir', 'reverse');
axis(ax_main, 'image', 'off');
hold(ax_main, 'on');

%% ========== PREPARE MESH CELL PATCHES ==========

qx = gutMesh(:,:,1);
qy = gutMesh(:,:,2);
[nMeshRows, nMeshCols] = size(qx);

% Create patch objects for each mesh cell
hPatches = [];
if useDiscreteCells
    fprintf('  Creating %d mesh cell patches...\n', (nMeshRows-1)*(nMeshCols-1));
    
    for row = 1:(nMeshRows-1)
        for col = 1:(nMeshCols-1)
            % Four corners of this cell
            cellX = [qx(row, col), qx(row, col+1), qx(row+1, col+1), qx(row+1, col)];
            cellY = [qy(row, col), qy(row, col+1), qy(row+1, col+1), qy(row+1, col)];
            
            % Create patch (will update color each frame)
            hp = patch(ax_main, cellX, cellY, [0.5 0.5 0.5], ...
                'EdgeColor', 'none', 'FaceAlpha', cellAlpha);
            hPatches(end+1) = hp;
        end
    end
end

%% ========== MESH GRID OVERLAY ==========

if showMeshGrid
    meshColorWithAlpha = [meshGridColor, meshGridAlpha];
    
    % Longitudinal lines
    for row = 1:meshGridSpacing:nMeshRows
        line(ax_main, qx(row, :), qy(row, :), ...
            'Color', meshColorWithAlpha, 'LineWidth', meshGridLineWidth);
    end
    
    % Transverse lines
    for col = 1:meshGridSpacing:nMeshCols
        line(ax_main, qx(:, col), qy(:, col), ...
            'Color', meshColorWithAlpha, 'LineWidth', meshGridLineWidth);
    end
    
    fprintf('  Mesh grid: %d x %d (showing every %d lines)\n', ...
        nMeshRows, nMeshCols, meshGridSpacing);
end

%% ========== SPARSE ARROWS (if enabled) ==========

if showArrows
    rowIdx = 1:arrowSpacing:nMeshRows;
    colIdx = 1:arrowSpacing:nMeshCols;
    [colGrid, rowGrid] = meshgrid(colIdx, rowIdx);
    sparseIdx = sub2ind([nMeshRows, nMeshCols], rowGrid(:), colGrid(:));
    
    qx_sparse = qx(sparseIdx);
    qy_sparse = qy(sparseIdx);
    
    % Use TRANSVERSE component - show as vertical arrows
    qv_init = velMultiple * gutMeshVelsPCoords(:,:,2,1);
    qv_sparse = qv_init(sparseIdx);
    
    hQuiv = quiver(ax_main, qx_sparse, qy_sparse, zeros(size(qv_sparse)), qv_sparse, 0, ...
        'Color', arrowColor, 'LineWidth', arrowLineWidth, ...
        'MaxHeadSize', 1.0, 'AutoScale', 'off');
end

%% ========== STATIC ANNOTATIONS ==========

% Timestamp
if showTimestamp
    hTime = text(ax_main, 12, 25, 't = 0.00 s', 'Color', 'white', ...
        'FontSize', 12, 'FontWeight', 'bold', 'BackgroundColor', [0 0 0 0.6], ...
        'Margin', 3, 'VerticalAlignment', 'top');
end

% Scale bar
if showScaleBar
    barY = dispRows - 20;
    barX = 20;
    line(ax_main, [barX barX+scaleBarPixels], [barY barY], 'Color', 'white', 'LineWidth', 4);
    line(ax_main, [barX barX], [barY-5 barY+5], 'Color', 'white', 'LineWidth', 2);
    line(ax_main, [barX+scaleBarPixels barX+scaleBarPixels], [barY-5 barY+5], 'Color', 'white', 'LineWidth', 2);
    text(ax_main, barX + scaleBarPixels/2, barY - 18, sprintf('%d Âµm', scaleBarMicrons), ...
        'Color', 'white', 'FontSize', 11, 'HorizontalAlignment', 'center', ...
        'BackgroundColor', [0 0 0 0.5]);
end

% Color legend - TRANSVERSE labels
if showColorLegend
    legX = dispCols - 130;
    legY = dispRows - 70;
    legWidth = 100;
    legHeight = 15;
    
    % Gradient
    legendGradient = zeros(legHeight, legWidth, 3);
    for gi = 1:legWidth
        t = (gi - 1) / (legWidth - 1);
        if t < 0.5
            blend = t * 2;
            color = expandColor * (1-blend) + [0.5 0.5 0.5] * blend;
            legendGradient(:, gi, 1) = color(1);
            legendGradient(:, gi, 2) = color(2);
            legendGradient(:, gi, 3) = color(3);
        else
            blend = (t - 0.5) * 2;
            color = [0.5 0.5 0.5] * (1-blend) + contractColor * blend;
            legendGradient(:, gi, 1) = color(1);
            legendGradient(:, gi, 2) = color(2);
            legendGradient(:, gi, 3) = color(3);
        end
    end
    
    image(ax_main, [legX legX+legWidth], [legY legY+legHeight], legendGradient);
    rectangle(ax_main, 'Position', [legX, legY, legWidth, legHeight], ...
        'EdgeColor', 'white', 'LineWidth', 1);
    
    % TRANSVERSE labels: -DV / +DV (dorsal-ventral direction)
    text(ax_main, legX - 5, legY + legHeight/2, '-DV', ...
        'Color', expandColor, 'FontSize', 9, 'FontWeight', 'bold', ...
        'HorizontalAlignment', 'right', 'VerticalAlignment', 'middle');
    text(ax_main, legX + legWidth + 5, legY + legHeight/2, '+DV', ...
        'Color', contractColor, 'FontSize', 9, 'FontWeight', 'bold', ...
        'HorizontalAlignment', 'left', 'VerticalAlignment', 'middle');
end

hold(ax_main, 'off');

%% ========== KYMOGRAPH PANEL (TRANSVERSE) ==========

if showKymograph
    ax_kymo = axes('Position', [0.70 0.20 0.28 0.72]);
    
    kymographLimit = max(abs(kymographMin), abs(kymographMax));
    imagesc(ax_kymo, qstXAxis, qstYAxis, qstMap, [-kymographLimit kymographLimit]);
    
    colormap(ax_kymo, 'jet');
    set(ax_kymo, 'YDir', 'normal');
    hold(ax_kymo, 'on');
    
    hTimeLine = line(ax_kymo, [qstXAxis(1) qstXAxis(end)], [0 0], ...
        'Color', 'white', 'LineWidth', 2);
    hMarkerL = plot(ax_kymo, qstXAxis(1), 0, '<', 'Color', 'white', ...
        'MarkerSize', 6, 'MarkerFaceColor', 'white');
    hMarkerR = plot(ax_kymo, qstXAxis(end), 0, '>', 'Color', 'white', ...
        'MarkerSize', 6, 'MarkerFaceColor', 'white');
    hold(ax_kymo, 'off');
    
    xlabel(ax_kymo, 'Position (Âµm)', 'Color', 'white', 'FontSize', 10);
    ylabel(ax_kymo, 'Time (s)', 'Color', 'white', 'FontSize', 10);
    title(ax_kymo, 'Kymograph (Transverse)', 'Color', 'white', 'FontSize', 11, 'FontWeight', 'bold');
    set(ax_kymo, 'XColor', 'white', 'YColor', 'white', 'Color', [0.1 0.1 0.1]);
    
    cb = colorbar(ax_kymo, 'Location', 'southoutside');
    cb.Color = 'white';
    cb.FontSize = 9;
    cb.Label.String = 'Contraction Velocity (Âµm/s)';
    cb.Label.Color = 'white';
end

%% ========== GET INITIAL FRAME SIZE ==========

drawnow;
pause(0.1);
testFrame = getframe(fig);
[frameHeight, frameWidth, ~] = size(testFrame.cdata);

%% ========== MAIN FRAME LOOP ==========

totalFrames = length(startingFrame:deltaF:endingFrame-1);
frameCount = 0;
progbar2 = waitbar(0, 'Generating PIV animation (TRANSVERSE)...');

for i = startingFrame:deltaF:endingFrame-1
    frameCount = frameCount + 1;
    
    if mod(frameCount, 50) == 0
        waitbar(frameCount/totalFrames, progbar2, ...
            sprintf('Frame %d of %d', frameCount, totalFrames));
    end
    
    %% Read current image
    curImage = imreadSubsampled(fullfile(filenames{i}.name), [1 resReduce numRows], [startingPosition resReduce endingPosition], 'Index', filenames{i}.index);
    if do_histEq
        curImage = (double(imhistmatch(curImage, firstImHistExample)) - minI) / (maxI - minI);
    else
        curImage = double(curImage);
    end
    
    curImageNorm = (curImage - min(curImage(:))) / (max(curImage(:)) - min(curImage(:)) + eps);
    
    %% Update image
    set(hImg, 'CData', curImageNorm);
    
    %% Get TRANSVERSE velocity field for this frame
    curIndex = min(i - (i ~= 1), size(gutMeshVelsPCoords, 4));
    velField = gutMeshVelsPCoords(:,:,2,curIndex);  % TRANSVERSE component
    
    %% Update cell colors
    if useDiscreteCells
        patchIdx = 1;
        for row = 1:(nMeshRows-1)
            for col = 1:(nMeshCols-1)
                % Average velocity over the 4 corners of this cell
                cellVel = mean([velField(row, col), velField(row, col+1), ...
                               velField(row+1, col), velField(row+1, col+1)]);
                
                % Normalize to [-1, 1]
                velNorm = cellVel / maxVelocityForColor;
                velNorm = max(-1, min(1, velNorm));
                
                % Determine color and transparency
                velMagnitude = abs(velNorm);
                
                if velNorm > 0
                    % Positive transverse - contract color (orange)
                    cellColor = contractColor * velNorm;
                else
                    % Negative transverse - expand color (blue)
                    cellColor = expandColor * (-velNorm);
                end
                
                % Scale alpha with velocity magnitude
                cellTransparency = velMagnitude * cellAlpha;
                
                set(hPatches(patchIdx), 'FaceColor', cellColor, 'FaceAlpha', cellTransparency);
                patchIdx = patchIdx + 1;
            end
        end
    end
    
    %% Update arrows (if enabled)
    if showArrows
        qv = velMultiple * velField;
        qv_sparse = qv(sparseIdx);
        set(hQuiv, 'UData', zeros(size(qv_sparse)), 'VData', qv_sparse);
    end
    
    %% Update timestamp
    if showTimestamp
        currentTime = (i - 1) / fps;
        set(hTime, 'String', sprintf('t = %.2f s', currentTime));
    end
    
    %% Update kymograph marker
    if showKymograph
        currentTime = (i - 1) / fps;
        set(hTimeLine, 'YData', [currentTime currentTime]);
        set(hMarkerL, 'YData', currentTime);
        set(hMarkerR, 'YData', currentTime);
    end
    
    %% Write frame
    drawnow limitrate;
    frame = getframe(fig);
    
    [fh, fw, ~] = size(frame.cdata);
    if fh ~= frameHeight || fw ~= frameWidth
        frame.cdata = imresize(frame.cdata, [frameHeight, frameWidth]);
    end
    
    writeVideo(writerObj, frame);
end

%% ========== CLEANUP ==========

close(progbar2);
close(writerObj);
close(fig);

fprintf('PIV movie (TRANSVERSE) saved to: %s\n', fullfile(curAnDir, PIVOutputName));

end
