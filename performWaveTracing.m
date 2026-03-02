% performWaveTracing - Loop through directories and run interactive wave tracing
%
% This dispatcher function loops through all checked directories and calls
% extractWaveMetrics for each dataset where the Waves checkbox is enabled
% and the "Use" checkbox is checked.
%
% Analogous to performMotilityDataAnalysis.m
%
% Inputs: Same signature as other dispatcher functions in the pipeline.
%   - bools column 6 = Waves checkbox
%   - bools column 8 = Use checkbox

function performWaveTracing(mainExperimentDirectoryContents, mainExperimentSubDirectoryContentsCell, mainAnalysisDirectory, analysisToPerform, analysisVariables, currentAnalysesPerformedFileName, interpolationOutputName)

%% Initialize variables
nDirectories = size(analysisToPerform, 2);
currentAnalysisFile = load(strcat(mainAnalysisDirectory, filesep, currentAnalysesPerformedFileName));
currentAnalysisPerformed = currentAnalysisFile.currentAnalysisPerformed;

%% Loop through all checked directories
for i = 1:nDirectories
    
    nSubDirectories = size(analysisToPerform(i).bools, 1);
    
    for j = 1:nSubDirectories
        
        % Check Waves checkbox (column 6) AND Use checkbox (column 8)
        if analysisToPerform(i).bools(j, 6) && analysisToPerform(i).bools(j, 8)
            
            curDir = strcat(mainAnalysisDirectory, filesep, ...
                mainExperimentDirectoryContents(i).name, filesep, ...
                mainExperimentSubDirectoryContentsCell{1, i}(j).name);
            
            % Check that interpolated data exists
            interpFile = fullfile(curDir, [interpolationOutputName '_Current.mat']);
            if ~exist(interpFile, 'file')
                fprintf('WARNING: Interpolated data not found for %s/%s - skipping wave tracing\n', ...
                    mainExperimentDirectoryContents(i).name, ...
                    mainExperimentSubDirectoryContentsCell{1, i}(j).name);
                continue;
            end
            
            % Run interactive wave tracing
            fprintf('\n--- Wave Tracing: %s / %s ---\n', ...
                mainExperimentDirectoryContents(i).name, ...
                mainExperimentSubDirectoryContentsCell{1, i}(j).name);
            
            try
                [~, ~] = extractWaveMetrics(curDir, analysisVariables, interpolationOutputName);
                
                % Update currentAnalysisPerformed
                currentAnalysisPerformed(i).bools(j, 6) = true;
                
                % Save currentAnalysisPerformed.mat
                save(strcat(mainAnalysisDirectory, filesep, currentAnalysesPerformedFileName), ...
                    'currentAnalysisPerformed', 'analysisVariables');
                
            catch ME
                fprintf('ERROR in wave tracing for %s/%s: %s\n', ...
                    mainExperimentDirectoryContents(i).name, ...
                    mainExperimentSubDirectoryContentsCell{1, i}(j).name, ...
                    ME.message);
            end
            
        end
    end
    
end

end
