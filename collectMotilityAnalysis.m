function fishParams = collectMotilityAnalysis( varargin )

%% Initialize variables

if( nargin < 1 )
        mainAnalysisDirectory = uigetdir(pwd, 'Main directory to contain/currently containing analysis');
    else
        mainAnalysisDirectory = varargin{ 1 };
end

[mainAnalysisDirectoryContents, mainAnalysisSubDirectoryContentsCell, nSubDirectories] = obtainDirectoryStructure(mainAnalysisDirectory);
currentAnalysisPerformedFile = load(strcat(mainAnalysisDirectory,filesep,'currentAnalysesPerformed.mat'));
currentAnalysisPerformed = currentAnalysisPerformedFile.currentAnalysisPerformed;
% disp('Warning: The function is not tested for accuracy since it was written on the fly. Consider writing your own');
index = 0;

%% Loop through all checked directories to collect motility parameters
for i=1:nSubDirectories
    
    % Obtain the current directory size
    % nSubSubDirectories = size(mainAnalysisDirectoryContents(i).name, 1);
    subDire=dir(strcat(mainAnalysisDirectory,filesep,mainAnalysisDirectoryContents(i).name));
    subDire(strncmp({subDire.name}, '.', 1)) = []; % Removes . and ..
    subDire([subDire.isdir]==0) = []; % removes non-directories from list
    subFishDirect(i).name={subDire.name};
    nSFD=size(subFishDirect(i).name,2);
    curFolder = mainAnalysisDirectoryContents(i).name;
    % Loop through all checked subdirectories to perform PIV
    for j=1:nSFD
        
        if(currentAnalysisPerformed(i).bools(j,8))
            
            index = index + 1;
            currentAnalysisPerformed(i).directory
            % ObtainCurrentDirectory
            curAnDir = strcat(mainAnalysisDirectory, filesep, mainAnalysisDirectoryContents(i).name, filesep, mainAnalysisSubDirectoryContentsCell{1, i}(j).name);
            paramsFile = load(strcat(curAnDir, filesep, 'motilityParameters_Current.mat'));
            fishParams(index).Folder = curFolder;
            fishParams(index).SubFolder = mainAnalysisSubDirectoryContentsCell{1, i}(j).name;
            fishParams(index).FFTPowerPeak = paramsFile.fftPowerPeak;
            fishParams(index).FFTPeakFreq = paramsFile.fftPeakFreq;
            fishParams(index).FFTRPowerPeakSTD = paramsFile.fftRPowerPeakSTD;
            fishParams(index).FFTRPowerPeakMin = paramsFile.fftRPowerPeakMin;
            fishParams(index).FFTRPowerPeakMax = paramsFile.fftRPowerPeakMax;
            fishParams(index).WaveFrequency = paramsFile.waveFrequency;
            fishParams(index).WaveSpeedSlope = paramsFile.waveSpeedSlope;
            fishParams(index).BByFPS = paramsFile.BByFPS;
            fishParams(index).SigB = paramsFile.sigB;
            fishParams(index).WaveFitRSquared = paramsFile.waveFitRSquared;
            %        fishParams(index).XCorrMaxima = paramsFile.xCorrMaxima;
            fishParams(index).AnalyzedDeltaMarkersOne = paramsFile.analyzedDeltaMarkers(1);
            if(~isnan(paramsFile.analyzedDeltaMarkers(1)))
                fishParams(index).AnalyzedDeltaMarkersTwo = paramsFile.analyzedDeltaMarkers(2);
            else
                fishParams(index).AnalyzedDeltaMarkersTwo = NaN;
            end
            fishParams(index).WaveAverageWidth = paramsFile.waveAverageWidth;
            
        end

    end
    
end

temp_table = struct2table(fishParams);
writetable(temp_table,strcat(mainAnalysisDirectory, filesep, 'fishParams.csv'))

%% Collect individual wave metrics from all datasets
allWaveMetrics = table();
for i=1:nSubDirectories
    subDire=dir(strcat(mainAnalysisDirectory,filesep,mainAnalysisDirectoryContents(i).name));
    subDire(strncmp({subDire.name}, '.', 1)) = [];
    subDire([subDire.isdir]==0) = [];
    nSFD=size({subDire.name},2);
    curFolder = mainAnalysisDirectoryContents(i).name;
    for j=1:nSFD
        if(currentAnalysisPerformed(i).bools(j,8))
            curAnDir = strcat(mainAnalysisDirectory, filesep, mainAnalysisDirectoryContents(i).name, filesep, mainAnalysisSubDirectoryContentsCell{1, i}(j).name);
            waveFile = fullfile(curAnDir, 'WaveMetrics.csv');
            if exist(waveFile, 'file')
                try
                    waveTable = readtable(waveFile);
                    nWaves = height(waveTable);
                    waveTable.Folder = repmat({curFolder}, nWaves, 1);
                    waveTable.SubFolder = repmat({mainAnalysisSubDirectoryContentsCell{1, i}(j).name}, nWaves, 1);
                    waveTable = movevars(waveTable, {'Folder', 'SubFolder'}, 'Before', 1);
                    allWaveMetrics = [allWaveMetrics; waveTable]; %#ok
                    fprintf('  Collected %d wave events from %s/%s\n', nWaves, curFolder, mainAnalysisSubDirectoryContentsCell{1, i}(j).name);
                catch ME
                    fprintf('  Warning: Could not read wave metrics from %s/%s: %s\n', curFolder, mainAnalysisSubDirectoryContentsCell{1, i}(j).name, ME.message);
                end
            end
        end
    end
end

if height(allWaveMetrics) > 0
    writetable(allWaveMetrics, strcat(mainAnalysisDirectory, filesep, 'allWaveMetrics.csv'));
    fprintf('Collected %d total wave events into allWaveMetrics.csv\n', height(allWaveMetrics));
else
    fprintf('No wave metrics files found to collect.\n');
end

%% Collect all QSTMap TIFFs (Transverse + Longitudinal) into a single subfolder
tiffCollectDir = fullfile(mainAnalysisDirectory, 'QSTMap_TIFFs_Collected');
tiffCount = 0;

for i=1:nSubDirectories
    subDire=dir(strcat(mainAnalysisDirectory,filesep,mainAnalysisDirectoryContents(i).name));
    subDire(strncmp({subDire.name}, '.', 1)) = [];
    subDire([subDire.isdir]==0) = [];
    nSFD=size({subDire.name},2);
    curFolder = mainAnalysisDirectoryContents(i).name;
    for j=1:nSFD
        if(currentAnalysisPerformed(i).bools(j,8))
            curAnDir = strcat(mainAnalysisDirectory, filesep, mainAnalysisDirectoryContents(i).name, filesep, mainAnalysisSubDirectoryContentsCell{1, i}(j).name);
            
            % Find QSTMap TIFF files in this directory (both Transverse and Longitudinal)
            tiffFiles = dir(fullfile(curAnDir, 'QSTMap_*_32bit_*.tif'));
            
            for k = 1:numel(tiffFiles)
                % Create collection folder on first hit
                if tiffCount == 0
                    if ~exist(tiffCollectDir, 'dir')
                        mkdir(tiffCollectDir);
                    end
                end
                
                srcPath = fullfile(curAnDir, tiffFiles(k).name);
                dstPath = fullfile(tiffCollectDir, tiffFiles(k).name);
                copyfile(srcPath, dstPath);
                tiffCount = tiffCount + 1;
            end
            
            % Also copy the combined README if it exists
            readmeFiles = dir(fullfile(curAnDir, 'QSTMap_README_*.txt'));
            for k = 1:numel(readmeFiles)
                if tiffCount > 0 || exist(tiffCollectDir, 'dir')
                    copyfile(fullfile(curAnDir, readmeFiles(k).name), ...
                             fullfile(tiffCollectDir, readmeFiles(k).name));
                end
            end
        end
    end
end

if tiffCount > 0
    fprintf('Collected %d QSTMap TIFF(s) into: %s\n', tiffCount, tiffCollectDir);
else
    fprintf('No QSTMap TIFFs found to collect.\n');
end

end

%% Auxiliary functions

% obtainDirectoryStructure returns directory structures given a directory
function [directoryContents, subDirectoryContentsCell, nSubDirectories] = obtainDirectoryStructure(directory)
    
    % Obtain main directory structure
    directoryContents = dir(directory); % Obtain all main directory contents
    directoryContents(~[directoryContents.isdir]) = []; % Remove non-directories
    directoryContents(strncmp({directoryContents.name}, '.', 1)) = []; % Removes . and .. and hidden files
    nSubDirectories = size(directoryContents, 1);
    subDirectoryContentsCell = cell(1, nSubDirectories);
    
    % Loop through all sub-directory contents to obtain contents
    if(nSubDirectories > 0)
        for i = 1:nSubDirectories
            
            % Obtain main directory structure
            subDirectoryContents = dir(strcat(directory, filesep, directoryContents(i).name)); % Obtain all sub-directory contents
            subDirectoryContents(~[subDirectoryContents.isdir]) = []; % Remove non-directories
            subDirectoryContents(strncmp({subDirectoryContents.name}, '.', 1)) = []; % Removes . and .. and hidden files
            subDirectoryContentsCell{i} = subDirectoryContents;
            
        end
    end
end
