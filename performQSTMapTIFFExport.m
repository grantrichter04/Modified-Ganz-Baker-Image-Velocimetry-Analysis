% performQSTMapTIFFExport - Loop through directories and export 32-bit TIFFs
%
% This dispatcher function loops through all checked directories and calls
% exportQSTMapTIFF for each dataset where the TIFF export checkbox is
% enabled and the "Use" checkbox is checked.
%
% Column layout: bools column 7 = TIFF, column 8 = Use

function performQSTMapTIFFExport(mainExperimentDirectoryContents, mainExperimentSubDirectoryContentsCell, mainAnalysisDirectory, analysisToPerform, analysisVariables, currentAnalysesPerformedFileName, interpolationOutputName)

%% Initialize variables
nDirectories = size(analysisToPerform, 2);
currentAnalysisFile = load(strcat(mainAnalysisDirectory, filesep, currentAnalysesPerformedFileName));
currentAnalysisPerformed = currentAnalysisFile.currentAnalysisPerformed;

progbar = waitbar(0, 'Preparing for TIFF export...');

%% Loop through all checked directories
for i = 1:nDirectories
    
    waitbar(i/nDirectories, progbar, ...
        sprintf('Exporting QSTMap TIFFs for folder %d of %d', i, nDirectories));
    
    nSubDirectories = size(analysisToPerform(i).bools, 1);
    folderName = mainExperimentDirectoryContents(i).name;
    
    for j = 1:nSubDirectories
        
        % Check TIFF checkbox (column 7) AND Use checkbox (column 8)
        if analysisToPerform(i).bools(j, 7) && analysisToPerform(i).bools(j, 8)
            
            subFolderName = mainExperimentSubDirectoryContentsCell{1, i}(j).name;
            curDir = strcat(mainAnalysisDirectory, filesep, folderName, filesep, subFolderName);
            
            % Build sample name from folder structure
            sampleName = [folderName '_' subFolderName];
            
            % Check that interpolated data exists
            interpFile = fullfile(curDir, [interpolationOutputName '_Current.mat']);
            if ~exist(interpFile, 'file')
                fprintf('WARNING: Interpolated data not found for %s — skipping TIFF export\n', sampleName);
                continue;
            end
            
            % Export the 32-bit TIFF
            try
                exportQSTMapTIFF(curDir, analysisVariables, interpolationOutputName, sampleName);
                
                currentAnalysisPerformed(i).bools(j, 7) = true;
                save(strcat(mainAnalysisDirectory, filesep, currentAnalysesPerformedFileName), ...
                    'currentAnalysisPerformed', 'analysisVariables');
                
            catch ME
                fprintf('ERROR exporting TIFF for %s: %s\n', sampleName, ME.message);
            end
            
        end
    end
    
end

close(progbar);

end
