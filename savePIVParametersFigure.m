% savePIVParametersFigure.m
%
% Generates and saves a figure showing the PIV analysis parameters.
% Shows both the raw PIV grid and the interpolated curvilinear gut mesh.
%
% Usage:
%   savePIVParametersFigure(curAnDir, curExpDir, analysisVariables)
%
% Enhanced February 2026 - Refined visualization

function savePIVParametersFigure(curAnDir, curExpDir, analysisVariables)

%% ========== PARSE PARAMETERS ==========

suffix = analysisVariables{1};
templateSize = str2double(analysisVariables{2});  % PIV interrogation window in pixels
fps = str2double(analysisVariables{3});
origMicronsPerPixel = str2double(analysisVariables{4});
origResReduction = str2double(analysisVariables{5});
maxFreq = str2double(analysisVariables{6});
minFreq = str2double(analysisVariables{7});

% Calculate derived values
effectiveScale = origMicronsPerPixel * origResReduction;
pivWindowMicrons = templateSize * effectiveScale;
pivWindowPixels = templateSize * origResReduction;  % Window size in display pixels

%% ========== LOAD MASK IF AVAILABLE ==========

maskFile = fullfile(curAnDir, 'maskVars_Current.mat');
if exist(maskFile, 'file')
    maskData = load(maskFile, 'gutOutlinePoly');
    gutOutlinePoly = maskData.gutOutlinePoly;
    hasMask = true;
else
    hasMask = false;
    warning('No mask file found - will show windows across entire image');
end

%% ========== LOAD INTERPOLATED MESH IF AVAILABLE ==========

meshFile = fullfile(curAnDir, 'interpolationData_Current.mat');
if exist(meshFile, 'file')
    meshData = load(meshFile, 'gutMesh');
    gutMesh = meshData.gutMesh;
    hasMesh = true;
else
    hasMesh = false;
    warning('No interpolated mesh found - will only show PIV grid');
end

%% ========== LOAD A SAMPLE IMAGE ==========

direc = dir(fullfile(curExpDir, suffix));
baseFilenames = {};
[baseFilenames{1:length(direc),1}] = deal(direc.name);
baseFilenames = sortrows(baseFilenames);

% Extract sample name from directory path
[~, sampleName] = fileparts(curExpDir);
if isempty(sampleName)
    [~, sampleName] = fileparts(fileparts(curExpDir));
end

% Get image info
if strcmp(suffix, '*.tif')
    info = imfinfo(fullfile(curExpDir, baseFilenames{1}));
    nImages = 0;
    for f = 1:length(baseFilenames)
        finfo = imfinfo(fullfile(curExpDir, baseFilenames{f}));
        nImages = nImages + size(finfo, 1);
    end
    sampleImage = imread(fullfile(curExpDir, baseFilenames{1}), 'Index', min(round(nImages/2), size(info,1)));
else
    nImages = length(baseFilenames);
    midIdx = round(nImages / 2);
    sampleImage = imread(fullfile(curExpDir, baseFilenames{midIdx}));
end

% Apply resolution reduction if needed
if origResReduction > 1
    sampleImage = sampleImage(1:origResReduction:end, 1:origResReduction:end);
end

[imgHeight, imgWidth] = size(sampleImage);
totalDuration = (nImages - 1) / fps;

%% ========== CREATE FIGURE ==========

fig = figure('Position', [50 50 1200 750], 'Color', 'white');

%% ========== TITLE BAR WITH SAMPLE NAME ==========

annotation('textbox', [0.05, 0.94, 0.90, 0.05], ...
    'String', sprintf('PIV Analysis Configuration: %s', sampleName), ...
    'EdgeColor', 'none', 'HorizontalAlignment', 'center', ...
    'FontSize', 16, 'FontWeight', 'bold', 'Color', [0.2 0.2 0.2]);

%% ========== MAIN IMAGE WITH PIV GRID AND MESH OVERLAY ==========

ax1 = axes('Position', [0.05 0.28 0.55 0.64]);

% Display image
imshow(sampleImage, []);
hold on;

% ===== VISUAL SETTINGS =====
overlayAlpha = 0.5;           % Unified alpha for all overlays (green outline + orange grid)
windowColor = [1 0.6 0];      % Orange
maskColor = [0 0.8 0];        % Green
lineWidth = 1.5;

% Create mask for determining where to draw grid
if hasMask
    % Create binary mask from polygon
    gutMask = poly2mask(gutOutlinePoly(:,1), gutOutlinePoly(:,2), imgHeight, imgWidth);
    
    % Draw the mask outline with matching opacity to orange grid
    % Use patch for consistent alpha control
    closedPoly = [gutOutlinePoly; gutOutlinePoly(1,:)];  % Close the polygon
    patch(closedPoly(:,1), closedPoly(:,2), maskColor, ...
        'FaceAlpha', 0, ...
        'EdgeColor', maskColor, ...
        'EdgeAlpha', overlayAlpha, ...
        'LineWidth', lineWidth);
    
    % Find bounding box of mask
    [maskRows, maskCols] = find(gutMask);
    minRow = min(maskRows);
    maxRow = max(maskRows);
    minCol = min(maskCols);
    maxCol = max(maskCols);
else
    % Use entire image
    gutMask = ones(imgHeight, imgWidth);
    minRow = 1;
    maxRow = imgHeight;
    minCol = 1;
    maxCol = imgWidth;
end

% Calculate grid of PIV windows
% PIV typically uses 50% overlap, so step size is half the window
stepSize = pivWindowPixels / 2;

% Generate grid positions
gridX = minCol:stepSize:(maxCol - pivWindowPixels);
gridY = minRow:stepSize:(maxRow - pivWindowPixels);

% Draw PIV window grid (only windows whose center is inside mask)
for gx = gridX
    for gy = gridY
        % Check if window center is inside mask
        centerX = gx + pivWindowPixels/2;
        centerY = gy + pivWindowPixels/2;
        
        if centerX > 0 && centerX <= imgWidth && centerY > 0 && centerY <= imgHeight
            if gutMask(round(centerY), round(centerX))
                % Draw window as a patch with transparency
                vx = [gx, gx + pivWindowPixels, gx + pivWindowPixels, gx];
                vy = [gy, gy, gy + pivWindowPixels, gy + pivWindowPixels];
                
                patch(vx, vy, windowColor, ...
                    'FaceAlpha', 0, ...
                    'EdgeColor', windowColor, ...
                    'EdgeAlpha', overlayAlpha * 0.15, ...  % Subtle grid, relative to main alpha
                    'LineWidth', 0.4);
            end
        end
    end
end

% Draw interpolated mesh overlay if available
if hasMesh
    qx = gutMesh(:,:,1);
    qy = gutMesh(:,:,2);
    [nMeshRows, nMeshCols] = size(qx);
    
    meshColor = [0.2 0.8 1.0];  % Cyan for mesh
    meshLineWidth = 1.2;
    
    % Draw longitudinal lines
    for row = 1:nMeshRows
        plot(qx(row, :), qy(row, :), '-', 'Color', [meshColor, overlayAlpha], 'LineWidth', meshLineWidth);
    end
    
    % Draw transverse lines
    for col = 1:nMeshCols
        plot(qx(:, col), qy(:, col), '-', 'Color', [meshColor, overlayAlpha], 'LineWidth', meshLineWidth);
    end
end

% Draw scale bar
scaleBarMicrons = 100;
scaleBarPixels = scaleBarMicrons / effectiveScale;
barX = 20;
barY = imgHeight - 30;
line([barX barX+scaleBarPixels], [barY barY], 'Color', 'white', 'LineWidth', 5);
line([barX barX], [barY-6 barY+6], 'Color', 'white', 'LineWidth', 3);
line([barX+scaleBarPixels barX+scaleBarPixels], [barY-6 barY+6], 'Color', 'white', 'LineWidth', 3);
text(barX + scaleBarPixels/2, barY - 15, sprintf('%d \mum', scaleBarMicrons), ...
    'Color', 'white', 'FontSize', 10, 'HorizontalAlignment', 'center', ...
    'FontWeight', 'bold', 'BackgroundColor', [0 0 0 0.7]);

hold off;
title('Sample Frame with Analysis Grids', 'FontSize', 13, 'FontWeight', 'bold');

%% ========== ZOOMED VIEW SHOWING 2x2 GRID WITH DISTINCT COLORS ==========

% Find a good region to zoom (center of mask)
if hasMask
    stats = regionprops(gutMask, 'Centroid');
    if ~isempty(stats)
        centroid = stats(1).Centroid;
        zoomCenterX = round(centroid(1));
        zoomCenterY = round(centroid(2));
    else
        zoomCenterX = round(imgWidth/2);
        zoomCenterY = round(imgHeight/2);
    end
else
    zoomCenterX = round(imgWidth/2);
    zoomCenterY = round(imgHeight/2);
end

% Zoom region should show exactly 2x2 windows with 50% overlap
zoomSize = pivWindowPixels * 2;  % Show 2 full window widths
zoomX1 = max(1, round(zoomCenterX - zoomSize/2));
zoomX2 = min(imgWidth, round(zoomCenterX + zoomSize/2));
zoomY1 = max(1, round(zoomCenterY - zoomSize/2));
zoomY2 = min(imgHeight, round(zoomCenterY + zoomSize/2));

% Draw zoom indicator rectangle on main image
axes(ax1);
hold on;
zoomIndicatorColor = [1 1 0];  % Yellow for visibility
rectangle('Position', [zoomX1, zoomY1, zoomX2-zoomX1, zoomY2-zoomY1], ...
    'EdgeColor', zoomIndicatorColor, 'LineWidth', 2, 'LineStyle', '-');
hold off;

% Create axes for zoomed view
ax2 = axes('Position', [0.65 0.45 0.32 0.47]);

% Extract zoomed region
zoomedRegion = sampleImage(zoomY1:zoomY2, zoomX1:zoomX2);

imshow(zoomedRegion, []);
hold on;

% Draw exactly 2x2 grid of windows with DISTINCT COLORS
localCenterX = (zoomX2 - zoomX1 + 1) / 2;
localCenterY = (zoomY2 - zoomY1 + 1) / 2;

% 4 distinct colors for the 4 windows
windowColors = {
    [1.0 0.4 0.0];    % Orange-red (top-left)
    [0.0 0.6 1.0];    % Blue (top-right)
    [0.8 0.2 0.8];    % Purple (bottom-left)
    [0.2 0.8 0.2]     % Green (bottom-right)
};

% Window positions with 50% overlap:
windowPositions = [
    -stepSize/2, -stepSize/2;  % Top-left
     stepSize/2, -stepSize/2;  % Top-right
    -stepSize/2,  stepSize/2;  % Bottom-left
     stepSize/2,  stepSize/2   % Bottom-right
];

for i = 1:size(windowPositions, 1)
    wx = localCenterX + windowPositions(i, 1) - pivWindowPixels/2;
    wy = localCenterY + windowPositions(i, 2) - pivWindowPixels/2;
    
    % Draw filled rectangle with transparency
    patch([wx, wx+pivWindowPixels, wx+pivWindowPixels, wx], ...
          [wy, wy, wy+pivWindowPixels, wy+pivWindowPixels], ...
          windowColors{i}, ...
          'FaceAlpha', 0.15, ...
          'EdgeColor', windowColors{i}, ...
          'LineWidth', 2.5);
end

% Add window size annotation in zoomed view
text(localCenterX, 18, sprintf('%d x %d px', templateSize, templateSize), ...
    'Color', [0.2 0.2 0.2], 'FontSize', 11, 'FontWeight', 'bold', ...
    'HorizontalAlignment', 'center', 'BackgroundColor', [1 1 1 0.9]);

hold off;
title('2x2 Windows with 50% Overlap', 'FontSize', 11, 'FontWeight', 'bold');

%% ========== COMPACT PARAMETERS PANEL ==========

% Create a compact table-style layout using annotations (which layer properly)
boxColor = [0.96 0.96 0.98];

% Background box
annotation('rectangle', [0.05, 0.03, 0.90, 0.22], ...
    'FaceColor', boxColor, 'EdgeColor', [0.8 0.8 0.8], 'LineWidth', 1);

% Section title
annotation('textbox', [0.05, 0.20, 0.90, 0.04], ...
    'String', 'Analysis Parameters', ...
    'EdgeColor', 'none', 'HorizontalAlignment', 'center', ...
    'FontSize', 12, 'FontWeight', 'bold');

% Spatial parameters
spatialParams = sprintf(['Window: %dx%d px (%.1fx%.1f \mum)  |  ' ...
    'Scale: %.3f \mum/px  |  Reduction: %dx'], ...
    templateSize, templateSize, pivWindowMicrons, pivWindowMicrons, ...
    effectiveScale, origResReduction);

% Temporal parameters
temporalParams = sprintf(['%d fps  |  %d frames  |  %.1f sec  |  ' ...
    'Freq: %.2fâ€“%.2f /min'], ...
    fps, nImages, totalDuration, minFreq, maxFreq);

annotation('textbox', [0.05, 0.13, 0.90, 0.04], ...
    'String', spatialParams, ...
    'EdgeColor', 'none', 'HorizontalAlignment', 'center', ...
    'FontSize', 9.5, 'FontName', 'FixedWidth');

annotation('textbox', [0.05, 0.06, 0.90, 0.04], ...
    'String', temporalParams, ...
    'EdgeColor', 'none', 'HorizontalAlignment', 'center', ...
    'FontSize', 9.5, 'FontName', 'FixedWidth');

%% ========== LEGEND (simple colored text) ==========

% Use simple colored text labels instead of TeX interpreter
legendX = 0.06;
legendY = 0.26;  % Above the parameter box
legendSpacing = 0.12;

annotation('textbox', [legendX, legendY, 0.10, 0.03], ...
    'String', 'PIV grid', 'EdgeColor', 'none', ...
    'Color', windowColor, 'FontSize', 9, 'FontWeight', 'bold');

if hasMask
    annotation('textbox', [legendX + legendSpacing, legendY, 0.12, 0.03], ...
        'String', 'Analysis region', 'EdgeColor', 'none', ...
        'Color', maskColor, 'FontSize', 9, 'FontWeight', 'bold');
end

if hasMesh
    annotation('textbox', [legendX + 2*legendSpacing, legendY, 0.20, 0.03], ...
        'String', 'Interpolated mesh (AP/DV)', 'EdgeColor', 'none', ...
        'Color', meshColor, 'FontSize', 9, 'FontWeight', 'bold');
end

% Add zoom indicator to legend
annotation('textbox', [legendX + 3*legendSpacing + 0.08, legendY, 0.12, 0.03], ...
    'String', 'Zoom region', 'EdgeColor', 'none', ...
    'Color', [0.8 0.8 0], 'FontSize', 9, 'FontWeight', 'bold');

%% ========== SAVE FIGURE ==========

% Save as PNG with date (consistent with other analysis figures)
saveas(fig, strcat(curAnDir, filesep, 'PIV_Parameters_', date), 'png');

% Save as MATLAB figure (most recent only, consistent with other figures)
saveas(fig, strcat(curAnDir, filesep, 'PIV_Parameters_Current'), 'fig');

fprintf('PIV parameters figure saved to:\n');
fprintf('  %s\n', fullfile(curAnDir, ['PIV_Parameters_' date '.png']));

close(fig);

end
