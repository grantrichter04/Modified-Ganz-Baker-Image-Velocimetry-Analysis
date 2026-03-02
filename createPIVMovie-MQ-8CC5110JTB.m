% createPIVMovie.m
%
% Unified PIV video visualization for both TRANSVERSE and LONGITUDINAL
% velocity components. The component is determined by analysisVariables{8}.
%
% Each mesh cell is colored by the same metric used in the kymograph:
%   TRANSVERSE:    2*(mean_dorsal - mean_ventral) of DV component
%                  Positive = squeeze, Negative = relax
%   LONGITUDINAL:  -mean(all DV rows) of AP component
%                  Positive = forward (posterior), Negative = backward
%
% Kymograph is displayed alongside the video with a time-tracking cursor.

function createPIVMovie(curAnDir, curExpDir, analysisVariables, PIVVideoParams, PIVOutputName, interpolationOutputName)

%% ========== CONFIGURATION ==========

useDiscreteCells = true;          % Show discrete colored cells
showKymograph = true;             % Show kymograph panel
showMeshGrid = false;             % Show mesh grid lines
showTimestamp = true;             % Show timestamp overlay
showScaleBar = true;              % Show scale bar
showColorLegend = true;           % Show color legend bar
showGutOutline = true;            % Show gut boundary outline

% Color settings (same colors, different labels per component)
warmColor = [1.0 0.5 0.1];       % Orange/warm = positive metric
coolColor = [0.1 0.5 1.0];       % Blue/cool = negative metric
maxVelocityForColor = 0;          % Max velocity for color scaling (0 = auto)
cellAlphaMax = 0.6;               % Maximum opacity at full velocity (0-1)
cellAlphaMin = 0.0;               % Minimum opacity at zero velocity

% Arrow settings
showArrows = true;               % Show velocity arrows on overlay
useRawVectors = true;            % true = raw PIV vectors (x,y), false = component only
                                  % NOTE: useRawVectors=true doubles memory usage.
arrowColor = [1 0 0];
arrowLineWidth = 1.5;
velMultiple = 20;
arrowSpacing = 3;

% Kymograph settings
usePercentileScaling = true;
kymographPercentiles = [1 99];

% Other display options
do_histEq = false;
gutOutlineColor = [0 1 0];
gutOutlineAlpha = 0.5;
gutOutlineWidth = 1.5;
meshGridAlpha = 0.15;

%% ========== DETERMINE COMPONENT MODE ==========

isLongitudinal = (size(analysisVariables, 2) >= 8 && strcmp(analysisVariables{8}, 'Longitudinal'));

if isLongitudinal
    componentIdx = 1;     % gutMeshVelsPCoords dimension 3 index
    componentName = 'Longitudinal';
    legendLabelNeg = 'bwd';
    legendLabelPos = 'fwd';
    kymoTitle = 'Kymograph (Longitudinal)';
    kymoColorbarLabel = 'Velocity (\mum/s)';
    fprintf('\n=== PIV VIDEO: LONGITUDINAL ===\n');
else
    componentIdx = 2;
    componentName = 'Transverse';
    legendLabelNeg = 'Relax';
    legendLabelPos = 'Squeeze';
    kymoTitle = 'Kymograph (Transverse)';
    kymoColorbarLabel = 'Contraction Velocity (\mum/s)';
    fprintf('\n=== PIV VIDEO: TRANSVERSE ===\n');
end

%% ========== LOAD DATA ==========

suffix = analysisVariables{1};
origResReduction = str2double(analysisVariables{5});
origMicronsPerPixel = str2double(analysisVariables{4});
fps = str2double(analysisVariables{3});

% Only load gutMeshVels (raw vectors) when needed — it doubles memory
if showArrows && useRawVectors
    load(fullfile(curAnDir, [interpolationOutputName '_Current.mat']), ...
        'gutMesh', 'gutMeshVels', 'gutMeshVelsPCoords', 'thetas');
    
    % Apply temporal smoothing to raw vectors (gutMeshVelsPCoords is already
    % smoothed during interpolation, but gutMeshVels is saved unsmoothed)
    temporalSmoothingFrames = 0;
    if size(analysisVariables, 2) >= 11
        temporalSmoothingFrames = str2double(analysisVariables{11});
        if isnan(temporalSmoothingFrames), temporalSmoothingFrames = 0; end
    end
    if temporalSmoothingFrames > 0
        sigma = temporalSmoothingFrames / 2.355;
        halfWidth = ceil(3 * sigma);
        kernelT = exp(-(-halfWidth:halfWidth).^2 / (2 * sigma^2));
        kernelT = kernelT / sum(kernelT);
        [nR, nC, ~, ~] = size(gutMeshVels);
        fprintf('  Smoothing raw vectors: %d-frame Gaussian (sigma=%.1f)\n', temporalSmoothingFrames, sigma);
        for ri = 1:nR
            for ci = 1:nC
                for comp = 1:2
                    gutMeshVels(ri, ci, comp, :) = conv(squeeze(gutMeshVels(ri, ci, comp, :)), kernelT, 'same');
                end
            end
        end
    end
else
    load(fullfile(curAnDir, [interpolationOutputName '_Current.mat']), ...
        'gutMesh', 'gutMeshVelsPCoords', 'thetas');
end

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

% Handle multi-page TIFFs
filenames = {};
for k = 1:amount
    info = imfinfo(fullfile(curExpDir, baseFilenames{k}));
    nPages = numel(info);
    for p = 1:nPages
        filenames{count}.name = baseFilenames{k};
        filenames{count}.index = p;
        count = count + 1;
    end
end

%% ========== VIDEO TIMING AND POSITION ==========

% PIVVideoParams values are percentages (0-100)
startTP = PIVVideoParams(1,1) / 100;
deltaF = PIVVideoParams(1,2);
endTP = PIVVideoParams(1,3) / 100;
startX = PIVVideoParams(2,1) / 100;
resReduceNew = PIVVideoParams(2,2);
endX = PIVVideoParams(2,3) / 100;
resReduce = resReduceNew * origResReduction;
micronsPerPixel = origMicronsPerPixel * resReduce;

nF = size(filenames, 2);
firstImInfo = imfinfo(fullfile(curExpDir, baseFilenames{1}));
numRows = firstImInfo(1).Height;
numCols = firstImInfo(1).Width;

startingFrame = round(nF * startTP + 1);
endingFrame = round(nF * endTP);
startingPosition = round(numCols * startX + 1);
endingPosition = round(numCols * endX);

dispRows = floor(numRows / resReduce);
dispCols = floor((endingPosition - startingPosition + 1) / resReduce);

firstIm = imreadSubsampled(fullfile(curExpDir, filenames{1}.name), [1 resReduce numRows], [startingPosition resReduce endingPosition], 'Index', filenames{1}.index);
if do_histEq
    firstImHistExample = firstIm;
    minI = double(min(firstIm(:)));
    maxI = double(max(firstIm(:)));
end
scale = origMicronsPerPixel * origResReduction;

%% ========== DETERMINE VELOCITY RANGE ==========

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

if hasGlobalLUT
    maxVelocityForColor = max(abs(globalLUTMin), abs(globalLUTMax));
    fprintf('  Using GLOBAL color range for overlay: +/-%.2f\n', maxVelocityForColor);
elseif maxVelocityForColor == 0
    sampleFrames = round(linspace(1, size(gutMeshVelsPCoords, 4), min(20, size(gutMeshVelsPCoords, 4))));
    allMetric = [];
    for sf = sampleFrames
        colMetric = computeColumnMetric(gutMeshVelsPCoords, sf, componentIdx, isLongitudinal);
        allMetric = [allMetric, colMetric];
    end
    maxVelocityForColor = prctile(abs(allMetric), 95);
    fprintf('  Auto-detected %s range: +/-%.2f um/s\n', componentName, maxVelocityForColor);
end

%% ========== KYMOGRAPH DATA ==========

if showKymograph
    if isLongitudinal
        qstMap = squeeze(-mean(gutMeshVelsPCoords(:,:,1,:), 1))';
    else
        nMeshRowsForKymo = size(gutMeshVelsPCoords, 1);
        qstMap = 2 * squeeze(mean(gutMeshVelsPCoords(floor(nMeshRowsForKymo/2)+1:end,:,2,:), 1) - ...
                             mean(gutMeshVelsPCoords(1:floor(nMeshRowsForKymo/2),:,2,:), 1))';
    end
    
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
    fprintf('  Kymograph (%s) velocity range: %.2f to %.2f\n', componentName, kymographMin, kymographMax);
end

%% ========== VIDEO WRITER ==========

% Build descriptive filename
[parentDir, subFolder] = fileparts(curAnDir);
[~, folder] = fileparts(parentDir);
sampleName = [folder '_' subFolder];
descriptiveOutputName = sprintf('PIVAnimation_%s_%s.mp4', componentName, sampleName);
writerObj = VideoWriter(fullfile(curAnDir, descriptiveOutputName), 'MPEG-4');
writerObj.Quality = 95;
open(writerObj);

%% ========== FIGURE SETUP ==========

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
    ax_main = axes(fig, 'Units', 'normalized', 'Position', [0.01 0.02 0.62 0.96]);
else
    ax_main = axes(fig, 'Units', 'normalized', 'Position', [0.01 0.02 0.98 0.96]);
end
set(ax_main, 'XTick', [], 'YTick', [], 'Box', 'off', 'Color', [0.15 0.15 0.15]);
hold(ax_main, 'on');

%% ========== INITIAL IMAGE ==========

firstImNorm = double(firstIm);
firstImNorm = (firstImNorm - min(firstImNorm(:))) / (max(firstImNorm(:)) - min(firstImNorm(:)) + eps);
hImg = imagesc(ax_main, firstImNorm);
colormap(ax_main, gray(256));
axis(ax_main, 'image');
set(ax_main, 'YDir', 'reverse');  % Image convention: row 1 at top
set(ax_main, 'XTick', [], 'YTick', []);

%% ========== MESH GEOMETRY ==========

qx = gutMesh(:,:,1);
qy = gutMesh(:,:,2);
[nMeshRows, nMeshCols] = size(qx);

%% ========== DISCRETE CELL PATCHES ==========

hPatches = gobjects(0);
if useDiscreteCells
    fprintf('  Creating %d mesh cell patches...\n', (nMeshRows-1)*(nMeshCols-1));
    for row = 1:(nMeshRows-1)
        for col = 1:(nMeshCols-1)
            cellX = [qx(row, col), qx(row, col+1), qx(row+1, col+1), qx(row+1, col)];
            cellY = [qy(row, col), qy(row, col+1), qy(row+1, col+1), qy(row+1, col)];
            hPatches(end+1) = patch(ax_main, cellX, cellY, [0.5 0.5 0.5], ...
                'FaceAlpha', 0, 'EdgeColor', 'none');
        end
    end
end

%% ========== MESH GRID LINES (optional) ==========

if showMeshGrid
    for row = 1:nMeshRows
        line(ax_main, qx(row, :), qy(row, :), ...
            'Color', [1 1 1 meshGridAlpha], 'LineWidth', 0.5);
    end
    for col = 1:nMeshCols
        line(ax_main, qx(:, col), qy(:, col), ...
            'Color', [1 1 1 meshGridAlpha], 'LineWidth', 0.5);
    end
    fprintf('  Mesh grid: %d x %d (showing every %d lines)\n', ...
        nMeshRows, nMeshCols, 1);
end

%% ========== GUT OUTLINE ==========

if showGutOutline && hasUserMask
    scaledPolyX = gutOutlinePoly(:,1) / resReduce;
    scaledPolyY = gutOutlinePoly(:,2) / resReduce;
    patch(ax_main, scaledPolyX, scaledPolyY, gutOutlineColor, ...
        'FaceAlpha', 0, 'EdgeColor', gutOutlineColor, ...
        'EdgeAlpha', gutOutlineAlpha, 'LineWidth', gutOutlineWidth);
end

%% ========== SPARSE ARROWS (if enabled) ==========

if showArrows
    rowIdx = 1:arrowSpacing:nMeshRows;
    colIdx = 1:arrowSpacing:nMeshCols;
    [colGrid, rowGrid] = meshgrid(colIdx, rowIdx);
    sparseIdx = sub2ind([nMeshRows, nMeshCols], rowGrid(:), colGrid(:));
    
    qx_sparse = qx(sparseIdx);
    qy_sparse = qy(sparseIdx);
    
    if useRawVectors
        % Raw PIV vectors in image coordinates
        qu_init = velMultiple * gutMeshVels(:,:,1,1);
        qv_init = velMultiple * gutMeshVels(:,:,2,1);
    elseif isLongitudinal
        % Longitudinal: horizontal arrows
        qu_init = velMultiple * gutMeshVelsPCoords(:,:,1,1);
        qv_init = zeros(nMeshRows, nMeshCols);
    else
        % Transverse: vertical arrows
        qu_init = zeros(nMeshRows, nMeshCols);
        qv_init = velMultiple * gutMeshVelsPCoords(:,:,2,1);
    end
    qu_sparse = qu_init(sparseIdx);
    qv_sparse = qv_init(sparseIdx);
    
    hQuiv = quiver(ax_main, qx_sparse, qy_sparse, qu_sparse, qv_sparse, 0, ...
        'Color', arrowColor, 'LineWidth', arrowLineWidth, ...
        'MaxHeadSize', 1.0, 'AutoScale', 'off');
end

%% ========== STATIC ANNOTATIONS ==========

% Timestamp
if showTimestamp
    hTime = text(ax_main, 12, 25, 't = 0.00 s', 'Color', 'white', ...
        'FontSize', 12, 'FontWeight', 'bold', ...
        'BackgroundColor', [0.5 0.5 0.5 0.5], 'Margin', 4);
end

% Scale bar
if showScaleBar
    scaleBarMicrons = 100;
    scaleBarPixels = scaleBarMicrons / micronsPerPixel;
    barX = 15;
    barY = dispRows - 35;
    
    line(ax_main, [barX barX+scaleBarPixels], [barY barY], 'Color', 'white', 'LineWidth', 3);
    line(ax_main, [barX barX], [barY-5 barY+5], 'Color', 'white', 'LineWidth', 2);
    line(ax_main, [barX+scaleBarPixels barX+scaleBarPixels], [barY-5 barY+5], 'Color', 'white', 'LineWidth', 2);
    text(ax_main, barX + scaleBarPixels/2, barY - 18, sprintf('%d \\mum', scaleBarMicrons), ...
        'Color', 'white', 'FontSize', 11, 'HorizontalAlignment', 'center', ...
        'BackgroundColor', [0 0 0 0.5]);
end

% Color legend
if showColorLegend
    legX = dispCols - 180;
    legY = dispRows - 55;
    legWidth = 100;
    legHeight = 15;
    
    % Gradient
    legendGradient = zeros(legHeight, legWidth, 3);
    for gi = 1:legWidth
        t = (gi - 1) / (legWidth - 1);
        if t < 0.5
            blend = t * 2;
            color = coolColor * (1-blend) + [0.5 0.5 0.5] * blend;
            legendGradient(:, gi, 1) = color(1);
            legendGradient(:, gi, 2) = color(2);
            legendGradient(:, gi, 3) = color(3);
        else
            blend = (t - 0.5) * 2;
            color = [0.5 0.5 0.5] * (1-blend) + warmColor * blend;
            legendGradient(:, gi, 1) = color(1);
            legendGradient(:, gi, 2) = color(2);
            legendGradient(:, gi, 3) = color(3);
        end
    end
    
    image(ax_main, [legX legX+legWidth], [legY legY+legHeight], legendGradient);
    rectangle(ax_main, 'Position', [legX, legY, legWidth, legHeight], ...
        'EdgeColor', 'white', 'LineWidth', 1);
    
    text(ax_main, legX - 5, legY + legHeight/2, legendLabelNeg, ...
        'Color', coolColor, 'FontSize', 9, 'FontWeight', 'bold', ...
        'HorizontalAlignment', 'right', 'VerticalAlignment', 'middle');
    text(ax_main, legX + legWidth + 5, legY + legHeight/2, legendLabelPos, ...
        'Color', warmColor, 'FontSize', 9, 'FontWeight', 'bold', ...
        'HorizontalAlignment', 'left', 'VerticalAlignment', 'middle');
end

%% ========== KYMOGRAPH PANEL ==========

if showKymograph
    ax_kymo = axes(fig, 'Units', 'normalized', 'Position', [0.72 0.12 0.26 0.82]);
    imagesc(ax_kymo, qstXAxis, qstYAxis, qstMap);
    set(ax_kymo, 'YDir', 'normal');
    caxis(ax_kymo, [kymographMin kymographMax]);
    colormap(ax_kymo, jet(256));
    xlabel(ax_kymo, 'Position (\mum)', 'Color', 'white');
    ylabel(ax_kymo, 'Time (s)', 'Color', 'white');
    title(ax_kymo, kymoTitle, 'Color', 'white', 'FontSize', 11, 'FontWeight', 'bold');
    set(ax_kymo, 'XColor', 'white', 'YColor', 'white', 'Color', [0.15 0.15 0.15]);
    
    % Colorbar
    cb = colorbar(ax_kymo, 'Location', 'southoutside', 'Color', 'white');
    cb.Label.String = kymoColorbarLabel;
    cb.Label.Color = 'white';
    
    % Time tracking line
    hold(ax_kymo, 'on');
    hTimeLine = plot(ax_kymo, [qstXAxis(1) qstXAxis(end)], [0 0], 'w-', 'LineWidth', 1.5);
    hMarkerL = plot(ax_kymo, qstXAxis(1), 0, 'w<', 'MarkerSize', 6, 'MarkerFaceColor', 'w');
    hMarkerR = plot(ax_kymo, qstXAxis(end), 0, 'w>', 'MarkerSize', 6, 'MarkerFaceColor', 'w');
end

%% ========== GET INITIAL FRAME SIZE ==========

drawnow;
pause(0.1);
testFrame = getframe(fig);
[frameHeight, frameWidth, ~] = size(testFrame.cdata);
clear testFrame;

%% ========== MAIN FRAME LOOP ==========

totalFrames = length(startingFrame:deltaF:endingFrame-1);
frameCount = 0;
progbar2 = waitbar(0, sprintf('Generating PIV animation (%s)...', componentName));

for i = startingFrame:deltaF:endingFrame-1
    frameCount = frameCount + 1;
    
    if mod(frameCount, 50) == 0
        waitbar(frameCount/totalFrames, progbar2, ...
            sprintf('Frame %d of %d', frameCount, totalFrames));
    end
    
    %% Read current image
    curImage = imreadSubsampled(fullfile(curExpDir, filenames{i}.name), [1 resReduce numRows], [startingPosition resReduce endingPosition], 'Index', filenames{i}.index);
    if do_histEq
        curImage = (double(imhistmatch(curImage, firstImHistExample)) - minI) / (maxI - minI);
    else
        curImage = double(curImage);
    end
    
    curImageNorm = (curImage - min(curImage(:))) / (max(curImage(:)) - min(curImage(:)) + eps);
    
    %% Update image
    set(hImg, 'CData', curImageNorm);
    
    %% Compute per-column metric for this frame (matches kymograph formula)
    curIndex = min(i - (i ~= 1), size(gutMeshVelsPCoords, 4));
    colMetric = computeColumnMetric(gutMeshVelsPCoords, curIndex, componentIdx, isLongitudinal);
    
    %% Update cell colors - all cells in a column share the same metric value
    if useDiscreteCells
        patchIdx = 1;
        for row = 1:(nMeshRows-1)
            for col = 1:(nMeshCols-1)
                cellVal = mean([colMetric(col), colMetric(min(col+1, nMeshCols))]);
                
                % Normalize to [-1, 1]
                velNorm = cellVal / maxVelocityForColor;
                velNorm = max(-1, min(1, velNorm));
                
                % Color based on direction
                if velNorm > 0
                    cellColor = warmColor;
                else
                    cellColor = coolColor;
                end
                
                % Alpha carries the magnitude
                velMagnitude = abs(velNorm);
                cellTransparency = cellAlphaMin + (cellAlphaMax - cellAlphaMin) * sqrt(velMagnitude);
                
                set(hPatches(patchIdx), 'FaceColor', cellColor, 'FaceAlpha', cellTransparency);
                patchIdx = patchIdx + 1;
            end
        end
    end
    
    %% Update arrows (if enabled)
    if showArrows
        if useRawVectors
            qu = velMultiple * gutMeshVels(:,:,1,curIndex);
            qv = velMultiple * gutMeshVels(:,:,2,curIndex);
            set(hQuiv, 'UData', qu(sparseIdx), 'VData', qv(sparseIdx));
        elseif isLongitudinal
            qu = velMultiple * gutMeshVelsPCoords(:,:,1,curIndex);
            set(hQuiv, 'UData', qu(sparseIdx), 'VData', zeros(size(qu(sparseIdx))));
        else
            qv = velMultiple * gutMeshVelsPCoords(:,:,2,curIndex);
            set(hQuiv, 'UData', zeros(size(qv(sparseIdx))), 'VData', qv(sparseIdx));
        end
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
    cdata = frame.cdata;
    
    [fh, fw, ~] = size(cdata);
    if fh ~= frameHeight || fw ~= frameWidth
        cdata = imresize(cdata, [frameHeight, frameWidth]);
    end
    
    writeVideo(writerObj, cdata);
    
    % Periodic garbage collection to prevent memory accumulation
    if mod(frameCount, 100) == 0
        java.lang.System.gc();
    end
end

%% ========== CLEANUP ==========

close(progbar2);
close(writerObj);
close(fig);

% Free large arrays to avoid OOM on subsequent movies
clear gutMeshVelsPCoords gutMeshVels gutMesh cdata hPatches filenames qstMap;

fprintf('PIV movie (%s) saved to: %s\n', upper(componentName), fullfile(curAnDir, descriptiveOutputName));

end

%% ========== HELPER FUNCTION ==========

function colMetric = computeColumnMetric(gutMeshVelsPCoords, frameIdx, componentIdx, isLongitudinal)
% Compute the per-column metric that matches the kymograph formula.
%   TRANSVERSE:    2*(mean_dorsal - mean_ventral)  → positive = squeeze
%   LONGITUDINAL:  -mean(all rows)                 → positive = forward

    velField = gutMeshVelsPCoords(:,:,componentIdx,frameIdx);
    
    if isLongitudinal
        colMetric = -mean(velField, 1);
    else
        nRows = size(velField, 1);
        halfRow = floor(nRows / 2);
        colMetric = 2 * (mean(velField(halfRow+1:end, :), 1) - mean(velField(1:halfRow, :), 1));
    end
end
