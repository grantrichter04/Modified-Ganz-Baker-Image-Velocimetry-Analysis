% exportQSTMapTIFF - Export BOTH transverse and longitudinal QSTMaps as 32-bit float TIFFs
%
% Exports two 32-bit floating-point TIFF files where pixel values directly
% encode velocity in micrometers/second. No colormap is applied — raw
% numerical values only. Signed values are preserved.
%
% Sign conventions:
%   TRANSVERSE:    Positive = contraction (inward squeeze)
%                  Negative = expansion (outward relaxation)
%   LONGITUDINAL:  Positive = forward (anterior-to-posterior flow)
%                  Negative = backward (posterior-to-anterior flow)
%
% TIME CONVENTION: Both TIFFs are flipped so that when opened in ImageJ,
% time increases upward — matching the kymograph display in the video.
% Row 1 (top of image) = latest time point, last row (bottom) = time 0.
%
% NOTE: These are orthogonal projections of the same velocity field. The
% full 2D velocity at each (position, time) point can be reconstructed
% from the two component TIFFs.
%
% Inputs:
%   - curDir: Path to the analysis directory for this dataset
%   - analysisVariables: Cell array of GUI parameters (scale, fps, etc.)
%   - interpolationOutputName: Name stem of the interpolated PIV .mat file
%   - sampleName: (Optional) String like 'FolderName_SubfolderName' for
%       the output filename. If omitted, extracts from curDir.
%
% Outputs:
%   - outputFilePaths: Cell array of full paths to the saved TIFF files
%                      {transversePath, longitudinalPath}
%
% Created: February 2026
% For use with the zebrafish gut motility analysis toolbox (Ganz et al., 2018)

function outputFilePaths = exportQSTMapTIFF(curDir, analysisVariables, interpolationOutputName, sampleName)

%% ========== HANDLE OPTIONAL ARGUMENTS ==========
if nargin < 4 || isempty(sampleName)
    [parentDir, subFolder] = fileparts(curDir);
    [~, folder] = fileparts(parentDir);
    sampleName = [folder '_' subFolder];
end

%% ========== LOAD DATA ==========
fprintf('\n=== EXPORTING 32-BIT QSTMap TIFFs (Transverse + Longitudinal) ===\n');
fprintf('Sample: %s\n', sampleName);

loadedInterpFile = load(strcat(curDir, filesep, interpolationOutputName, '_Current.mat'));

gutMesh = loadedInterpFile.gutMesh;
gutMeshVelsPCoords = loadedInterpFile.gutMeshVelsPCoords;

scale = str2double(analysisVariables{4}) * str2double(analysisVariables{5});
fps = str2double(analysisVariables{3});
velocityScale = scale * fps;  % pixels/frame -> um/s conversion factor

%% ========== COMMON PARAMETERS ==========
markerNumStart = 1;
markerNumEnd = size(gutMesh, 2);
nFrames = size(gutMeshVelsPCoords, 4);
ordinateValues = int16(1:nFrames);
nMeshRows = size(gutMeshVelsPCoords, 1);
halfRow = floor(nMeshRows / 2);

translateMarkerNumToMicron = scale * round(mean(diff(squeeze(gutMesh(1,:,1,1)))));
secondsPerFrame = 1.0 / fps;

%% ========== COMPUTE BOTH QSTMaps ==========

% TRANSVERSE: 2*(mean_dorsal - mean_ventral) of DV component
% Positive = contraction (inward squeeze)
surfaceValuesT = 2 * squeeze( ...
    mean(gutMeshVelsPCoords(halfRow+1:end, markerNumStart:markerNumEnd, 2, ordinateValues), 1) - ...
    mean(gutMeshVelsPCoords(1:halfRow, markerNumStart:markerNumEnd, 2, ordinateValues), 1)) * velocityScale;

% LONGITUDINAL: -mean(all DV rows) of AP component
% Positive = forward (anterior-to-posterior)
surfaceValuesL = squeeze( ...
    -mean(gutMeshVelsPCoords(:, markerNumStart:markerNumEnd, 1, ordinateValues), 1)) * velocityScale;

% Transpose so rows=time, cols=position, then FLIP so time increases upward
qstMapT = single(flipud(surfaceValuesT'));
qstMapL = single(flipud(surfaceValuesL'));

%% ========== BUILD FILENAMES ==========
spatialStr = sprintf('%.2fum', translateMarkerNumToMicron);
temporalStr = sprintf('%.4fs', secondsPerFrame);

fileNameT = sprintf('QSTMap_Transverse_%s_32bit_%sPx_%sPx.tif', sampleName, spatialStr, temporalStr);
fileNameL = sprintf('QSTMap_Longitudinal_%s_32bit_%sPx_%sPx.tif', sampleName, spatialStr, temporalStr);

outputPathT = fullfile(curDir, fileNameT);
outputPathL = fullfile(curDir, fileNameL);
outputFilePaths = {outputPathT, outputPathL};

%% ========== WRITE TRANSVERSE TIFF ==========
fprintf('\n--- Transverse ---\n');
fprintf('  Size: %d rows (time) x %d cols (position)\n', size(qstMapT, 1), size(qstMapT, 2));
fprintf('  Value range: [%.4f, %.4f] um/s\n', min(qstMapT(:)), max(qstMapT(:)));

writeSingleQSTMapTIFF(outputPathT, qstMapT, 'Transverse', sampleName, ...
    translateMarkerNumToMicron, secondsPerFrame, fps, scale, nMeshRows, curDir, ...
    'Transverse (DV) velocity', ...
    '2*(mean_dorsal_half - mean_ventral_half) of DV velocity', ...
    'Positive = contraction (inward squeezing), Negative = expansion (outward relaxation)');

fprintf('  Saved: %s\n', outputPathT);

%% ========== WRITE LONGITUDINAL TIFF ==========
fprintf('\n--- Longitudinal ---\n');
fprintf('  Size: %d rows (time) x %d cols (position)\n', size(qstMapL, 1), size(qstMapL, 2));
fprintf('  Value range: [%.4f, %.4f] um/s\n', min(qstMapL(:)), max(qstMapL(:)));

writeSingleQSTMapTIFF(outputPathL, qstMapL, 'Longitudinal', sampleName, ...
    translateMarkerNumToMicron, secondsPerFrame, fps, scale, nMeshRows, curDir, ...
    'Longitudinal (AP) velocity', ...
    '-mean(all DV rows) of AP velocity', ...
    'Positive = forward (anterior-to-posterior), Negative = backward (posterior-to-anterior)');

fprintf('  Saved: %s\n', outputPathL);

%% ========== COMBINED README ==========
readmeFileName = sprintf('QSTMap_README_%s.txt', sampleName);
readmeFilePath = fullfile(curDir, readmeFileName);
fid = fopen(readmeFilePath, 'w');

fprintf(fid, '32-bit Float TIFF Export: Velocity QSTMaps\n');
fprintf(fid, '============================================\n\n');
fprintf(fid, 'Sample: %s\n', sampleName);
fprintf(fid, 'Export date: %s\n\n', datestr(now, 'yyyy-mm-dd HH:MM:SS'));

fprintf(fid, 'FILES:\n');
fprintf(fid, '  1. %s\n', fileNameT);
fprintf(fid, '  2. %s\n\n', fileNameL);

fprintf(fid, 'PIXEL VALUES:\n');
fprintf(fid, '  Units: um/s (micrometers per second)\n');
fprintf(fid, '  Both files are 32-bit float -- open directly in ImageJ/Fiji.\n\n');

fprintf(fid, 'SIGN CONVENTIONS:\n');
fprintf(fid, '  Transverse:    Positive = contraction (inward squeeze)\n');
fprintf(fid, '                 Negative = expansion (outward relaxation)\n');
fprintf(fid, '                 Threshold: pixels > +0.5 um/s = contraction events\n');
fprintf(fid, '  Longitudinal:  Positive = forward (anterior-to-posterior flow)\n');
fprintf(fid, '                 Negative = backward (posterior-to-anterior flow)\n\n');

fprintf(fid, 'RECONSTRUCTING FULL VELOCITY:\n');
fprintf(fid, '  These are orthogonal projections of the same velocity field.\n');
fprintf(fid, '  Speed magnitude = sqrt(Transverse^2 + Longitudinal^2)\n');
fprintf(fid, '  Note: Transverse uses dorsal-ventral difference formula,\n');
fprintf(fid, '  so it represents the contraction/expansion rate, not raw DV velocity.\n\n');

fprintf(fid, 'TIME CONVENTION:\n');
fprintf(fid, '  Images are FLIPPED to match kymograph display.\n');
fprintf(fid, '  When viewed in ImageJ: time increases UPWARD (bottom=t0, top=latest).\n\n');

fprintf(fid, 'IMAGE DIMENSIONS:\n');
fprintf(fid, '  Rows (Y-axis): Time  - %d pixels, %.4f s/pixel (%.2f fps)\n', ...
    size(qstMapT, 1), secondsPerFrame, fps);
fprintf(fid, '  Cols (X-axis): Position along gut  - %d pixels, %.4f um/pixel\n', ...
    size(qstMapT, 2), translateMarkerNumToMicron);
fprintf(fid, '  NOTE: Each column = one PIV mesh marker, NOT one raw image pixel.\n\n');

fprintf(fid, 'VALUE RANGES:\n');
fprintf(fid, '  Transverse:    [%.4f, %.4f] um/s (mean %.4f)\n', ...
    min(qstMapT(:)), max(qstMapT(:)), mean(qstMapT(:)));
fprintf(fid, '  Longitudinal:  [%.4f, %.4f] um/s (mean %.4f)\n\n', ...
    min(qstMapL(:)), max(qstMapL(:)), mean(qstMapL(:)));

fprintf(fid, 'IMAGEJ/FIJI QUICKSTART:\n');
fprintf(fid, '  1. File > Open (reads as 32-bit float automatically)\n');
fprintf(fid, '  2. Image > Properties: Pixel width=%.4f um, Pixel height=%.4f s\n', ...
    translateMarkerNumToMicron, secondsPerFrame);
fprintf(fid, '  3. Image > Adjust > Threshold to find contraction events\n');
fprintf(fid, '  4. Analyze > Measure to quantify\n\n');

fprintf(fid, 'SOURCE: %s\n', curDir);
fclose(fid);

fprintf('\n  README: %s\n', readmeFilePath);
fprintf('=== TIFF EXPORT COMPLETE ===\n\n');

end

%% ========== HELPER: WRITE A SINGLE 32-BIT TIFF ==========
function writeSingleQSTMapTIFF(outputPath, qstMap, componentName, sampleName, ...
    spatialRes, temporalRes, fps, scale, nMeshRows, curDir, ...
    componentDesc, formulaDesc, signDesc)

    t = Tiff(outputPath, 'w');

    tagstruct = struct();
    tagstruct.ImageLength = size(qstMap, 1);
    tagstruct.ImageWidth = size(qstMap, 2);
    tagstruct.Photometric = Tiff.Photometric.MinIsBlack;
    tagstruct.BitsPerSample = 32;
    tagstruct.SamplesPerPixel = 1;
    tagstruct.SampleFormat = Tiff.SampleFormat.IEEEFP;
    tagstruct.RowsPerStrip = size(qstMap, 1);
    tagstruct.PlanarConfiguration = Tiff.PlanarConfiguration.Chunky;
    tagstruct.Compression = Tiff.Compression.None;
    tagstruct.Software = 'Zebrafish Gut Motility Toolbox (Ganz et al., 2018)';
    tagstruct.ResolutionUnit = Tiff.ResolutionUnit.None;
    tagstruct.XResolution = 1.0 / spatialRes;
    tagstruct.YResolution = fps;

    metadataStr = sprintf([ ...
        'QSTMap_%s_32bit\n' ...
        'Sample: %s\n' ...
        'Units: um/s (micrometers per second)\n' ...
        'Component: %s\n' ...
        'Formula: %s\n' ...
        'Sign: %s\n' ...
        'Time convention: FLIPPED (time increases upward)\n' ...
        'Spatial_resolution_um_per_pixel: %.6f\n' ...
        'Temporal_resolution_s_per_pixel: %.6f\n' ...
        'FPS: %.2f\n' ...
        'Scale_um_per_image_pixel: %.6f\n' ...
        'N_mesh_rows: %d\n' ...
        'Source: %s\n' ...
        'Exported: %s\n'], ...
        componentName, sampleName, componentDesc, formulaDesc, signDesc, ...
        spatialRes, temporalRes, fps, scale, nMeshRows, curDir, ...
        datestr(now, 'yyyy-mm-dd HH:MM:SS'));

    tagstruct.ImageDescription = metadataStr;

    t.setTag(tagstruct);
    t.write(qstMap);
    t.close();

end
