% obtainMotilityMasks.m (ENHANCED)
%
% Loops through each directory and subdirectory to create masks.
% Now passes templateSize to show PIV grid preview during mask drawing.
%
% Inputs: (same as original)

function obtainMotilityMasks(mainExperimentDirectory, mainExperimentDirectoryContents, mainExperimentSubDirectoryContentsCell, mainAnalysisDirectory, analysisToPerform, analysisVariables, currentAnalysesPerformedFileName, maskFileOutputName)

%% Initialize variables
nDirectories = size(analysisToPerform, 2);
currentAnalysisFile = load(strcat(mainAnalysisDirectory, filesep, currentAnalysesPerformedFileName));
currentAnalysisPerformed = currentAnalysisFile.currentAnalysisPerformed;

% Extract template size for grid preview
templateSize = str2double(analysisVariables{2});

%% Loop through all checked directories to obtain image masks
for i = 1:nDirectories
    
    % Obtain the current directory size
    nSubDirectories = size(analysisToPerform(i).bools, 1);
    
    % Loop through all checked subdirectories to perform PIV
    for j = 1:nSubDirectories
        
        % If we want to analyze it, do so, else skip
        if (analysisToPerform(i).bools(j,2) && analysisToPerform(i).bools(j,8))
            
            % Obtain current directory
            curDir = strcat(mainExperimentDirectory, filesep, mainExperimentDirectoryContents(i).name, filesep, mainExperimentSubDirectoryContentsCell{1, i}(j).name);
            
            % Perform mask creation (now with templateSize for grid preview)
            [gutOutline, gutOutlinePoly, gutMiddleTop, gutMiddleBottom, gutMiddlePolyTop, gutMiddlePolyBottom] = ...
                obtainMotilityMask(curDir, analysisVariables{1}, str2double(analysisVariables{5}), templateSize);
            
            % Save mask files
            curAnDir = strcat(mainAnalysisDirectory, filesep, mainExperimentDirectoryContents(i).name, filesep, mainExperimentSubDirectoryContentsCell{1, i}(j).name);
            save(strcat(curAnDir, filesep, maskFileOutputName, '_Current'), ...
                'gutOutline', 'gutOutlinePoly', 'gutMiddleTop', 'gutMiddleBottom', 'gutMiddlePolyTop', 'gutMiddlePolyBottom');
            save(strcat(curAnDir, filesep, maskFileOutputName, '_', date), ...
                'gutOutline', 'gutOutlinePoly', 'gutMiddleTop', 'gutMiddleBottom', 'gutMiddlePolyTop', 'gutMiddlePolyBottom');
            
            % Generate PIV parameters figure (now that we have the mask)
            try
                savePIVParametersFigure(curAnDir, curDir, analysisVariables);
            catch ME
                warning('Could not generate PIV parameters figure: %s', ME.message);
            end
            
            % Update currentAnalysisPerformed
            currentAnalysisPerformed(i).bools(j,2) = true;
            
            % Save currentAnalysisPerformed
            save(strcat(mainAnalysisDirectory, filesep, currentAnalysesPerformedFileName), 'currentAnalysisPerformed', 'analysisVariables');
            
        end
    end
    
end

end
