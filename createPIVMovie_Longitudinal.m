% createPIVMovie_Longitudinal.m
% 
% Video visualization showing LONGITUDINAL velocity component.
% Matches the longitudinal analysis version of obtainMotilityParameters.
% 
% Each mesh cell is colored according to its measured LONGITUDINAL velocity:
%   - Blue = backward motion (toward anterior)
%   - Orange = forward motion (toward posterior)
%   - Intensity = velocity magnitude
%
% Kymograph shows longitudinal QSTMap with percentile-based scaling.
%
% January 2026

function createPIVMovie(curAnDir, curExpDir, analysisVariables, PIVVideoParams, PIVOutputName, interpolationOutputName)

%% ========== CONFIGURABLE PARAMETERS ==========

% Visualization mode
useDiscreteCells = true;          % Show discrete colored cells (vs smooth field)

% Color settings
forwardColor = [1.0 0.5 0.1];     % Orange for forward motion
backwardColor = [0.1 0.5 1.0];    % Blue for backward motion  
maxVelocityForColor = 0;          % Max velocity for color scaling (0 = auto)
cellAlphaMax = 0.6;               % Maximum opacity at full velocity (0-1)
cellAlphaMin = 0.0;               % Minimum opacity at zero velocity

% Mesh grid overlay
showMeshGrid = true;               % Overlay the mesh grid lines
meshGridColor = [0.3 1.0 0.3];    % Bright green
meshGridLineWidth = 1.0;           % Line thickness
meshGridSpacing = 1;               % Show every Nth grid line
meshGridAlpha = 0.10;               % Transparency (0=invisible, 1=opaque)

% Optional sparse arrows
showArrows = true;                % Usually false with discrete cells
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

%% ========== DETERMINE VELOCITY RANGE ==========

%% ========== DETERMINE VELOCITY RANGE (LONGITUDINAL) ==========

% Check if user specified a global color range in the GUI
globalLUTMin = [];
globalLUTMax = [];
if size(analysisVariables, 2) >= 10
    if ~strcmpi(analysisVariables{9}, 'auto')
        globalLUTMin = str2double(analysisVariables{9});
    end
    if ~strcmpi(analysisVariables{10}, 'auto')
        globalLUTMax = str2double(analysisVariables{10});
    end
end
hasGlobalLUT = ~isempty(globalLUTMin) && ~isempty(globalLUTMax) && ~isnan(globalLUTMin) && ~isnan(globalLUTMax);

% Use LONGITUDINAL flow metric (-mean across DV) for color range
if hasGlobalLUT
    maxVelocityForColor = max(abs(globalLUTMin), abs(globalLUTMax));
    fprintf('  Using GLOBAL color range for overlay: +/-%.2f\n', maxVelocityForColor);
elseif maxVelocityForColor == 0
    sampleFrames = round(linspace(1, size(gutMeshVelsPCoords, 4), min(20, size(gutMeshVelsPCoords, 4))));
    allFlowVals = [];
    for sf = sampleFrames
        velFrame = gutMeshVelsPCoords(:,:,1,sf);
        fMetric = -mean(velFrame, 1);  % Same formula as kymograph
        allFlowVals = [allFlowVals, fMetric];
    end
    maxVelocityForColor = prctile(abs(allFlowVals), 95);
    fprintf('  Auto-detected LONGITUDINAL flow range: +/-%.2f um/s\n', maxVelocityForColor);
end

%% ========== KYMOGRAPH DATA (LONGITUDINAL) ==========

if showKymograph
    % LONGITUDINAL: simple mean across gut width
    qstMap = squeeze(-mean(gutMeshVelsPCoords(:,:,1,:), 1))';
    scale = origMicronsPerPixel * origResReduction;
    translateMarkerNumToMicron = scale * round(mean(diff(squeeze(gutMesh(1,:,1,1)))));
    qstXAxis = (0:size(qstMap,2)-1) * translateMarkerNumToMicron;
    qstYAxis = (0:size(qstMap,1)-1) / fps;
    
    % Percentile-based scaling for kymograph (overridden by global LUT if set)
    if hasGlobalLUT
        kymographMin = globalLUTMin;
        kymographMax = globalLUTMax;
        fprintf('  Using GLOBAL color range for kymograph: [%.2f, %.2f]\n', kymographMin, kymographMax);
    elseif usePercentileScaling
        kymographMin = prctile(qstMap(:), kymographPercentiles(1));
        kymographMax = prctile(qstMap(:), kymographPercentiles(2));
    else
        kymographMin = min(qstMap(:));
        kymographMax = max(qstMap(:));
    end
    fprintf('  Kymograph (LONGITUDINAL) velocity range: %.2f to %.2f\n', kymographMin, kymographMax);
end

%% ========== HISTOGRAM EQ PREP ==========

if do_histEq
    firstIm = imreadSubsampled(fullfile(filenames{1}.name), [1 resReduce numRows], [startingPosition resReduce endingPosition], 'Index', filenames{1}.index);
    firstImHistExample = histeq(firstIm);
    maxI = double(max(firstImHistExample(:)));
    minI = double(min(firstImHistExample(:)));
end

%% ========== SETUP VIDEO WRITER ==========

% Build descriptive filename: PIVAnimation_Longitudinal_<Folder>_<SubFolder>.mp4
[parentDir, subFolder] = fileparts(curAnDir);
[~, folder] = fileparts(parentDir);
sampleName = [folder '_' subFolder];
descriptiveOutputName = sprintf('PIVAnimation_Longitudinal_%s.mp4', sampleName);
writerObj = VideoWriter(fullfile(curAnDir, descriptiveOutputName), 'MPEG-4');
writerObj.Quality = 95;
open(writerObj);

%% ========== CREATE FIGURE ==========

if showKymograph
    figWidth = 800;
    figHeight = 350;
else
    figWidth = 600;
    figHeight = 400;
end

fig = figure('Position', [100 100 figWidth figHeight], ...
    'Visible', 'on', 'Resize', 'off', ...
    'MenuBar', 'none', 'ToolBar', 'none');
set(fig, 'Renderer', 'opengl', 'Color', [0.15 0.15 0.15]);
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
                'EdgeColor', 'none', 'FaceAlpha', cellAlphaMin);
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
    
    % Use LONGITUDINAL component
    qu_init = velMultiple * gutMeshVelsPCoords(:,:,1,1);
    qu_sparse = qu_init(sparseIdx);
    
    hQuiv = quiver(ax_main, qx_sparse, qy_sparse, qu_sparse, zeros(size(qu_sparse)), 0, ...
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
    text(ax_main, barX + scaleBarPixels/2, barY - 18, sprintf('%d \mum', scaleBarMicrons), ...
        'Color', 'white', 'FontSize', 11, 'HorizontalAlignment', 'center', ...
        'BackgroundColor', [0 0 0 0.5]);
end

% Color legend - LONGITUDINAL labels
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
            color = backwardColor * (1-blend) + [0.5 0.5 0.5] * blend;
            legendGradient(:, gi, 1) = color(1);
            legendGradient(:, gi, 2) = color(2);
            legendGradient(:, gi, 3) = color(3);
        else
            blend = (t - 0.5) * 2;
            color = [0.5 0.5 0.5] * (1-blend) + forwardColor * blend;
            legendGradient(:, gi, 1) = color(1);
            legendGradient(:, gi, 2) = color(2);
            legendGradient(:, gi, 3) = color(3);
        end
    end
    
    image(ax_main, [legX legX+legWidth], [legY legY+legHeight], legendGradient);
    rectangle(ax_main, 'Position', [legX, legY, legWidth, legHeight], ...
        'EdgeColor', 'white', 'LineWidth', 1);
    
    % LONGITUDINAL labels: backward/forward
    text(ax_main, legX - 5, legY + legHeight/2, 'bwd', ...
        'Color', backwardColor, 'FontSize', 9, 'FontWeight', 'bold', ...
        'HorizontalAlignment', 'right', 'VerticalAlignment', 'middle');
    text(ax_main, legX + legWidth + 5, legY + legHeight/2, 'fwd', ...
        'Color', forwardColor, 'FontSize', 9, 'FontWeight', 'bold', ...
        'HorizontalAlignment', 'left', 'VerticalAlignment', 'middle');
end

hold(ax_main, 'off');

%% ========== KYMOGRAPH PANEL (LONGITUDINAL) ==========

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
    
    xlabel(ax_kymo, 'Position (\mum)', 'Color', 'white', 'FontSize', 10);
    ylabel(ax_kymo, 'Time (s)', 'Color', 'white', 'FontSize', 10);
    title(ax_kymo, 'Kymograph (Longitudinal)', 'Color', 'white', 'FontSize', 11, 'FontWeight', 'bold');
    set(ax_kymo, 'XColor', 'white', 'YColor', 'white', 'Color', [0.1 0.1 0.1]);
    
    cb = colorbar(ax_kymo, 'Location', 'southoutside');
    cb.Color = 'white';
    cb.FontSize = 9;
    cb.Label.String = 'Velocity (\mum/s)';
    cb.Label.Color = 'white';
end

%% ========== GET INITIAL FRAME SIZE ==========

drawnow;
pause(0.1);
testFrameData = print(fig, '-RGBImage', '-r0');
[frameHeight, frameWidth, ~] = size(testFrameData);
clear testFrameData;

%% ========== MAIN FRAME LOOP ==========

totalFrames = length(startingFrame:deltaF:endingFrame-1);
frameCount = 0;
progbar2 = waitbar(0, 'Generating PIV animation (LONGITUDINAL)...');

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
    
    %% Get LONGITUDINAL velocity metric for this frame
    % Use SAME formula as kymograph: -mean(all DV rows) per column
    % This ensures overlay colors match kymograph colors
    curIndex = min(i - (i ~= 1), size(gutMeshVelsPCoords, 4));
    velField = gutMeshVelsPCoords(:,:,1,curIndex);  % LONGITUDINAL component
    flowMetric = -mean(velField, 1);  % Negated DV-average per column (matches kymograph)
    
    %% Update cell colors
    if useDiscreteCells
        patchIdx = 1;
        for row = 1:(nMeshRows-1)
            for col = 1:(nMeshCols-1)
                % Use column-averaged flow metric (matches kymograph)
                cellVel = flowMetric(col);
                
                % Normalize to [-1, 1]
                velNorm = cellVel / maxVelocityForColor;
                velNorm = max(-1, min(1, velNorm));
                
                % Full-intensity color based on direction only
                if velNorm > 0
                    cellColor = forwardColor;    % Orange for forward
                else
                    cellColor = backwardColor;   % Blue for backward
                end
                
                % Alpha carries the magnitude (sqrt scaling for better
                % perceptual visibility at moderate velocities)
                velMagnitude = abs(velNorm);
                cellTransparency = cellAlphaMin + (cellAlphaMax - cellAlphaMin) * sqrt(velMagnitude);
                
                set(hPatches(patchIdx), 'FaceColor', cellColor, 'FaceAlpha', cellTransparency);
                patchIdx = patchIdx + 1;
            end
        end
    end
    
    %% Update arrows (if enabled)
    if showArrows
        qu = velMultiple * velField;
        qu_sparse = qu(sparseIdx);
        set(hQuiv, 'UData', qu_sparse, 'VData', zeros(size(qu_sparse)));
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
    frameData = print(fig, '-RGBImage', '-r0');
    
    [fh, fw, ~] = size(frameData);
    if fh ~= frameHeight || fw ~= frameWidth
        frameData = imresize(frameData, [frameHeight, frameWidth]);
    end
    
    writeVideo(writerObj, frameData);
    
    % Periodic garbage collection to prevent memory accumulation
    if mod(frameCount, 100) == 0
        java.lang.System.gc();
    end
end

%% ========== CLEANUP ==========

close(progbar2);
close(writerObj);
close(fig);

clear gutMesh gutMeshVels gutMeshVelsPCoords thetas qstMap filenames frameData hPatches;

fprintf('PIV movie (LONGITUDINAL) saved to: %s\n', fullfile(curAnDir, descriptiveOutputName));

end
