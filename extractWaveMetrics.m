% extractWaveMetrics - Interactive individual wave event analysis from QSTMaps
%
% This function displays the QSTMap (velocity magnitude visualization) for 
% a single dataset and allows the user to manually trace individual peristaltic
% wave events visible as diagonal streaks. For each traced wave, it calculates:
%   - Wave propagation speed (um/s) from the slope of the traced line
%   - Spatial extent (um) of the wave along the gut axis
%   - Peak velocity amplitude (um/s) as a proxy for contraction strength
%   - Duration (s) of the wave event
%
% The module generates:
%   1. A CSV spreadsheet with one row per traced wave and all metrics
%   2. A summary figure showing the annotated QSTMap and metric distributions
%
% Inputs:
%   - curDir: Path to the analysis directory for this dataset
%   - analysisVariables: Cell array of GUI parameters (scale, fps, etc.)
%   - interpolationOutputName: Name stem of the interpolated PIV .mat file
%
% Outputs:
%   - waveMetrics: Structure array with fields for each traced wave event
%   - summaryFigHandle: Handle to the summary figure
%
% Usage within pipeline:
%   Called by performWaveTracing.m, which loops through selected directories.
%   Requires that PIV and interpolation have already been completed.
%
% Interactive controls:
%   - Left-click twice to define start and end of a wave trace
%   - Press Enter (or right-click) when finished tracing all waves
%   - After each trace, metrics are displayed and the user can accept or undo
%
% Created: February 2026
% For use with the zebrafish gut motility analysis toolbox (Ganz et al., 2018)

function [waveMetrics, summaryFigHandle] = extractWaveMetrics(curDir, analysisVariables, interpolationOutputName)

%% ========== CONFIGURATION ==========
% Percentile-based scaling for the QSTMap display (matches obtainMotilityParameters)
usePercentileScale = true;
QSTMapPercentiles = [1, 99];  % [lower, upper] percentiles for color scaling

% Visual settings for wave trace overlays
traceLineWidth = 2;
traceMarkerSize = 8;
traceLabelFontSize = 10;
% Color cycle for distinguishing different wave traces
traceColors = [
    0.85, 0.33, 0.10;   % orange-red
    0.00, 0.45, 0.74;   % blue
    0.47, 0.67, 0.19;   % green
    0.93, 0.69, 0.13;   % gold
    0.49, 0.18, 0.56;   % purple
    0.30, 0.75, 0.93;   % light blue
    0.64, 0.08, 0.18;   % dark red
    0.00, 0.62, 0.45;   % teal
];

%% ========== LOAD DATA AND INITIALIZE VARIABLES ==========
fprintf('\n=== INDIVIDUAL WAVE TRACING MODULE ===\n');
fprintf('Loading interpolated PIV data from: %s\n', curDir);

% Load the processed PIV output (same file used by obtainMotilityParameters)
loadedInterpFile = load(strcat(curDir, filesep, interpolationOutputName, '_Current.mat'));

% Extract key variables from the loaded data
gutMesh = loadedInterpFile.gutMesh;
gutMeshVelsPCoords = loadedInterpFile.gutMeshVelsPCoords;

% Parse analysis variables (same convention as obtainMotilityParameters)
scale = str2double(analysisVariables{4}) * str2double(analysisVariables{5});  % microns/pixel after rescaling
fps = str2double(analysisVariables{3});  % frames per second
velocityScale = scale * fps;  % pixels/frame -> um/s conversion factor

% Determine which velocity component to analyze based on the GUI selection
if size(analysisVariables, 2) >= 8 && strcmp(analysisVariables{8}, 'Longitudinal')
    velocityComponent = 'Longitudinal';
else
    velocityComponent = 'Transverse';
end

% Compute spatial conversion factor: how many microns per marker position
translateMarkerNumToMicron = scale * round(mean(diff(squeeze(gutMesh(1,:,1,1)))));

% Define the spatial and temporal ranges (use full dataset)
markerNumStart = 1;
markerNumEnd = size(gutMesh, 2);
nFrames = size(gutMeshVelsPCoords, 4);

% Build the axis vectors in physical units
% X-axis: position along gut in microns
xAxisMicrons = (markerNumStart-1) * translateMarkerNumToMicron : (markerNumEnd-1) * translateMarkerNumToMicron;
% Y-axis: time in seconds
frameIndices = int16(1:nFrames);
yAxisSeconds = double(frameIndices) / fps;

%% ========== COMPUTE THE QSTMAP SURFACE ==========
% The surface values depend on which velocity component is selected.
% Longitudinal: average AP velocity (negated for convention: positive = anterior-to-posterior)
% Transverse: top-bottom difference in DV velocity (captures contraction/expansion)

if strcmp(velocityComponent, 'Longitudinal')
    % Longitudinal QSTMap: average across the DV mesh dimension, component 1 (AP)
    surfaceValues = squeeze(-mean(gutMeshVelsPCoords(:, markerNumStart:markerNumEnd, 1, frameIndices), 1)) * velocityScale;
    componentLabel = 'Longitudinal';
    fprintf('Analyzing LONGITUDINAL velocity component.\n');
else
    % Transverse QSTMap: difference between bottom and top halves, component 2 (DV)
    % Factor of 2 matches the convention in obtainMotilityParameters
    surfaceValues = 2 * squeeze( ...
        mean(gutMeshVelsPCoords(end/2:end, markerNumStart:markerNumEnd, 2, frameIndices), 1) - ...
        mean(gutMeshVelsPCoords(1:end/2, markerNumStart:markerNumEnd, 2, frameIndices), 1)) * velocityScale;
    componentLabel = 'Transverse';
    fprintf('Analyzing TRANSVERSE velocity component.\n');
end

% surfaceValues is [nMarkers x nFrames], so displaying it transposed puts
% x (position) on horizontal axis and t (time) on vertical axis, matching
% the QSTMap convention used throughout the pipeline.

%% ========== DETERMINE COLOR SCALING ==========
if usePercentileScale
    cLow = prctile(surfaceValues(:), QSTMapPercentiles(1));
    cHigh = prctile(surfaceValues(:), QSTMapPercentiles(2));
    colorScale = [cLow, cHigh];
else
    colorScale = [];  % Let MATLAB auto-scale
end

%% ========== DISPLAY THE QSTMAP FOR INTERACTIVE TRACING ==========
traceFig = figure('Name', sprintf('Wave Tracing - %s', componentLabel), ...
    'NumberTitle', 'off', 'Units', 'normalized', 'Position', [0.05, 0.1, 0.65, 0.8]);

% Display the QSTMap. Note: surfaceValues' transposes so rows=time, cols=position
% imshow with XData and YData maps array indices to physical coordinates
traceAx = axes('Parent', traceFig);
if ~isempty(colorScale)
    imshow(surfaceValues', colorScale, 'InitialMagnification', 'fit', ...
        'XData', [xAxisMicrons(1), xAxisMicrons(end)], ...
        'YData', [yAxisSeconds(1), yAxisSeconds(end)], ...
        'Parent', traceAx);
else
    imshow(surfaceValues', [], 'InitialMagnification', 'fit', ...
        'XData', [xAxisMicrons(1), xAxisMicrons(end)], ...
        'YData', [yAxisSeconds(1), yAxisSeconds(end)], ...
        'Parent', traceAx);
end
set(traceAx, 'YDir', 'normal');
colormap(traceAx, 'jet');
axis(traceAx, 'on');
axis(traceAx, 'fill');
colorbar(traceAx);
title(traceAx, sprintf('QSTMap %s — Click to trace waves (Enter to finish)', componentLabel), ...
    'FontSize', 16, 'FontWeight', 'bold');
ylabel(traceAx, 'Time (s)', 'FontSize', 14);
xlabel(traceAx, 'Position along gut (\mum)', 'FontSize', 14);
set(traceAx, 'FontSize', 12, 'FontWeight', 'bold');
hold(traceAx, 'on');

%% ========== INTERACTIVE WAVE TRACING LOOP ==========
% The user repeatedly clicks two points to define the start and end of each
% wave event. After each pair of clicks, the metrics are calculated and
% displayed. The user presses Enter to stop tracing.

waveMetrics = struct([]);  % Will grow as waves are added
waveCount = 0;
traceHandles = {};  % Store graphics handles for each trace (for potential undo)

fprintf('\n--- Interactive Wave Tracing ---\n');
fprintf('Left-click to set the START of a wave, then click again for the END.\n');
fprintf('Press ENTER when you are done tracing waves.\n\n');

continueTracing = true;

while continueTracing
    
    % --- Get first click (wave start) ---
    title(traceAx, sprintf('Wave #%d: Click the START of the wave (Enter to finish)', waveCount + 1), ...
        'FontSize', 16, 'FontWeight', 'bold');
    [x1, y1, button1] = ginput(1);
    
    % Check if user pressed Enter or right-clicked to finish
    if isempty(x1) || (~isempty(button1) && button1 == 3 && waveCount > 0)
        continueTracing = false;
        fprintf('Tracing complete. %d waves traced.\n', waveCount);
        break;
    end
    
    % --- Get second click (wave end) ---
    title(traceAx, sprintf('Wave #%d: Click the END of the wave', waveCount + 1), ...
        'FontSize', 16, 'FontWeight', 'bold');
    
    % Show a temporary marker at the start point so user can see where they clicked
    tempMarker = plot(traceAx, x1, y1, 'wo', 'MarkerSize', traceMarkerSize, 'LineWidth', 2);
    
    [x2, y2, button2] = ginput(1);
    
    % Remove temporary marker
    if isvalid(tempMarker)
        delete(tempMarker);
    end
    
    % Check if user pressed Enter or right-clicked to finish
    if isempty(x2) || (~isempty(button2) && button2 == 3 && waveCount > 0)
        continueTracing = false;
        fprintf('Tracing complete. %d waves traced.\n', waveCount);
        break;
    end
    
    % --- Calculate wave metrics from the two endpoints ---
    % The endpoints are in physical coordinates (microns, seconds)
    
    % Spatial extent: total distance along gut axis covered by the wave
    spatialExtent_um = abs(x2 - x1);  % microns
    
    % Duration: temporal length of the wave event
    duration_s = abs(y2 - y1);  % seconds
    
    % Wave propagation speed: spatial distance / temporal duration
    % Guard against division by zero if user clicks at same time
    if duration_s > 0
        waveSpeed_umps = spatialExtent_um / duration_s;  % microns/second
    else
        waveSpeed_umps = NaN;
        warning('Duration is zero — wave speed cannot be calculated for this trace.');
    end
    
    % --- Sample velocity data along the traced line to find peak amplitude ---
    % Convert the physical coordinates back to array indices to sample surfaceValues
    % surfaceValues is [nMarkers x nFrames]
    
    % Map x coordinates (microns) to marker indices
    % xAxisMicrons goes from (markerNumStart-1)*translate to (markerNumEnd-1)*translate
    markerIdx1 = (x1 / translateMarkerNumToMicron) + 1;  % 1-indexed marker number
    markerIdx2 = (x2 / translateMarkerNumToMicron) + 1;
    
    % Map y coordinates (seconds) to frame indices
    frameIdx1 = y1 * fps;  % frame number (fractional is fine for interpolation)
    frameIdx2 = y2 * fps;
    
    % Sample along the line using linear interpolation
    % Generate ~100 sample points (or more for longer traces)
    nSamples = max(100, round(max(spatialExtent_um, duration_s * 10)));
    sampleT = linspace(0, 1, nSamples);
    sampleMarkerIdx = markerIdx1 + sampleT * (markerIdx2 - markerIdx1);
    sampleFrameIdx = frameIdx1 + sampleT * (frameIdx2 - frameIdx1);
    
    % Clamp indices to valid ranges for interpolation
    sampleMarkerIdx = max(1, min(size(surfaceValues, 1), sampleMarkerIdx));
    sampleFrameIdx = max(1, min(size(surfaceValues, 2), sampleFrameIdx));
    
    % Use interp2 to sample the surface along the traced path
    % interp2 expects (column_coords, row_coords, data, query_cols, query_rows)
    % surfaceValues(marker, frame), so marker is row, frame is column
    [frameGrid, markerGrid] = meshgrid(1:size(surfaceValues, 2), 1:size(surfaceValues, 1));
    sampledVelocities = interp2(frameGrid, markerGrid, surfaceValues, ...
        sampleFrameIdx, sampleMarkerIdx, 'linear', NaN);
    
    % Peak amplitude: maximum absolute velocity along the traced path
    % Using absolute value since waves can have positive or negative velocity
    peakAmplitude_umps = max(abs(sampledVelocities), [], 'omitnan');
    
    % Also compute the mean amplitude along the path as a secondary metric
    meanAmplitude_umps = mean(abs(sampledVelocities), 'omitnan');
    
    % --- Store results for this wave ---
    waveCount = waveCount + 1;
    colorIdx = mod(waveCount - 1, size(traceColors, 1)) + 1;
    currentColor = traceColors(colorIdx, :);
    
    waveMetrics(waveCount).WaveNumber = waveCount;
    waveMetrics(waveCount).PropagationSpeed_umps = waveSpeed_umps;
    waveMetrics(waveCount).SpatialExtent_um = spatialExtent_um;
    waveMetrics(waveCount).PeakAmplitude_umps = peakAmplitude_umps;
    waveMetrics(waveCount).MeanAmplitude_umps = meanAmplitude_umps;
    waveMetrics(waveCount).Duration_s = duration_s;
    waveMetrics(waveCount).StartPosition_um = min(x1, x2);
    waveMetrics(waveCount).EndPosition_um = max(x1, x2);
    waveMetrics(waveCount).StartTime_s = min(y1, y2);
    waveMetrics(waveCount).EndTime_s = max(y1, y2);
    waveMetrics(waveCount).VelocityComponent = componentLabel;
    
    % --- Draw the trace on the QSTMap ---
    hLine = plot(traceAx, [x1, x2], [y1, y2], '-', ...
        'Color', currentColor, 'LineWidth', traceLineWidth);
    hStart = plot(traceAx, x1, y1, 'o', ...
        'Color', currentColor, 'MarkerFaceColor', currentColor, ...
        'MarkerSize', traceMarkerSize);
    hEnd = plot(traceAx, x2, y2, 's', ...
        'Color', currentColor, 'MarkerFaceColor', currentColor, ...
        'MarkerSize', traceMarkerSize);
    
    % Add a label near the midpoint of the line showing the wave number and speed
    midX = (x1 + x2) / 2;
    midY = (y1 + y2) / 2;
    labelStr = sprintf('#%d: %.1f \\mum/s', waveCount, waveSpeed_umps);
    hLabel = text(traceAx, midX, midY, labelStr, ...
        'Color', currentColor, 'FontSize', traceLabelFontSize, ...
        'FontWeight', 'bold', 'BackgroundColor', [1, 1, 1, 0.7], ...
        'HorizontalAlignment', 'center', 'VerticalAlignment', 'bottom');
    
    % Store handles for potential undo
    traceHandles{waveCount} = [hLine, hStart, hEnd, hLabel];
    
    % --- Print metrics to console ---
    fprintf('Wave #%d:\n', waveCount);
    fprintf('  Speed:     %.2f um/s\n', waveSpeed_umps);
    fprintf('  Extent:    %.1f um\n', spatialExtent_um);
    fprintf('  Duration:  %.2f s\n', duration_s);
    fprintf('  Peak Amp:  %.3f um/s\n', peakAmplitude_umps);
    fprintf('  Mean Amp:  %.3f um/s\n', meanAmplitude_umps);
    fprintf('  Path:      (%.1f um, %.2f s) -> (%.1f um, %.2f s)\n', x1, y1, x2, y2);
    
    % --- Auto-accept the trace and continue ---
    fprintf('  -> Wave #%d accepted.\n', waveCount);
    
end

%% ========== HANDLE CASE WHERE NO WAVES WERE TRACED ==========
if waveCount == 0
    fprintf('No waves were traced. Returning empty results.\n');
    summaryFigHandle = [];
    close(traceFig);
    return;
end

%% ========== RESTORE THE TRACING FIGURE TITLE ==========
title(traceAx, sprintf('QSTMap %s — %d waves traced', componentLabel, waveCount), ...
    'FontSize', 16, 'FontWeight', 'bold');

%% ========== EXPORT WAVE METRICS TO CSV ==========
% Build a table from the wave metrics structure
metricsTable = struct2table(waveMetrics);

% Construct the output filename following the pipeline convention
% Pattern: <descriptiveName>_<component>_<date>.csv
csvFilename = sprintf('WaveMetrics_%s_%s.csv', componentLabel, date);
csvFullPath = strcat(curDir, filesep, csvFilename);

% Also save a "Current" version that gets overwritten each time
csvCurrentPath = strcat(curDir, filesep, sprintf('WaveMetrics_%s_Current.csv', componentLabel));

writetable(metricsTable, csvFullPath);
writetable(metricsTable, csvCurrentPath);
fprintf('\nWave metrics saved to:\n  %s\n  %s\n', csvFullPath, csvCurrentPath);

% Also save as .mat for programmatic access
matFilename = sprintf('WaveMetrics_%s_%s.mat', componentLabel, date);
matCurrentFilename = sprintf('WaveMetrics_%s_Current.mat', componentLabel);
save(strcat(curDir, filesep, matFilename), 'waveMetrics');
save(strcat(curDir, filesep, matCurrentFilename), 'waveMetrics');
fprintf('  %s\n  %s\n', matFilename, matCurrentFilename);

%% ========== SAVE TRACING FIGURE AND CLOSE ==========
% Save the tracing figure (annotated QSTMap from the interactive session)
tracePngName = sprintf('WaveTracing_%s_%s.png', componentLabel, date);
saveas(traceFig, strcat(curDir, filesep, tracePngName), 'png');
fprintf('Tracing figure saved to: %s\n', tracePngName);
close(traceFig);

summaryFigHandle = [];  % No separate summary figure

%% ========== PRINT FINAL SUMMARY TO CONSOLE ==========
speeds = [waveMetrics.PropagationSpeed_umps];
extents = [waveMetrics.SpatialExtent_um];
durations = [waveMetrics.Duration_s];
amplitudes = [waveMetrics.PeakAmplitude_umps];

fprintf('\n=== WAVE METRICS SUMMARY (%s) ===\n', componentLabel);
fprintf('Number of waves traced: %d\n', waveCount);
fprintf('Propagation speed:  %.2f +/- %.2f um/s  (range: %.2f - %.2f)\n', ...
    mean(speeds, 'omitnan'), std(speeds, 'omitnan'), min(speeds), max(speeds));
fprintf('Spatial extent:     %.1f +/- %.1f um   (range: %.1f - %.1f)\n', ...
    mean(extents, 'omitnan'), std(extents, 'omitnan'), min(extents), max(extents));
fprintf('Peak amplitude:     %.3f +/- %.3f um/s (range: %.3f - %.3f)\n', ...
    mean(amplitudes, 'omitnan'), std(amplitudes, 'omitnan'), min(amplitudes), max(amplitudes));
fprintf('Duration:           %.2f +/- %.2f s    (range: %.2f - %.2f)\n', ...
    mean(durations, 'omitnan'), std(durations, 'omitnan'), min(durations), max(durations));
fprintf('================================\n\n');

end
