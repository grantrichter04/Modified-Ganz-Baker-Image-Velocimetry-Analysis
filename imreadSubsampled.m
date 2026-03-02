function im = imreadSubsampled(filepath, rowRange, colRange, varargin)
% imreadSubsampled - Read an image with subsampling and optional cropping.
%
% This function replaces two deprecated imread parameters:
%   1. 'PixelRegion' — subsamples/crops on read (removed in newer MATLAB)
%   2. 'Index'       — reads a specific frame from multi-page TIFFs
%
% It reads the full image (converting 'Index' to positional syntax if
% needed), then subsamples rows and columns in memory.
%
% Usage:
%   im = imreadSubsampled(filepath, [rowStart rowStep rowEnd], [colStart colStep colEnd])
%   im = imreadSubsampled(filepath, [rS rStep rE], [cS cStep cE], 'Index', frameNum)
%
% The row/col ranges follow the same [start step end] convention that
% PixelRegion used: start at 'start', take every 'step'-th pixel, stop at
% or before 'end'.

    % --- Handle the deprecated 'Index' parameter ---
    % Newer MATLAB no longer accepts imread(..., 'Index', N).
    % Instead, use imread(filename, N) with frame number as positional arg.
    frameNum = [];
    filteredArgs = {};
    k = 1;
    while k <= length(varargin)
        if ischar(varargin{k}) && strcmpi(varargin{k}, 'Index')
            % Extract the frame number and skip both 'Index' and its value
            frameNum = varargin{k+1};
            k = k + 2;
        else
            filteredArgs{end+1} = varargin{k}; %#ok<AGROW>
            k = k + 1;
        end
    end

    % Read the full image with appropriate syntax
    if ~isempty(frameNum)
        % New positional syntax: imread(filename, frameNumber, ...)
        im = imread(filepath, frameNum, filteredArgs{:});
    else
        im = imread(filepath, filteredArgs{:});
    end

    % --- Apply subsampling / cropping ---
    rowStart = rowRange(1);
    rowStep  = rowRange(2);
    rowEnd   = rowRange(3);
    colStart = colRange(1);
    colStep  = colRange(2);
    colEnd   = colRange(3);

    % Clamp to actual image dimensions to avoid out-of-bounds errors
    [nRows, nCols, ~] = size(im);
    rowEnd = min(rowEnd, nRows);
    colEnd = min(colEnd, nCols);

    % Subsample and/or crop
    im = im(rowStart:rowStep:rowEnd, colStart:colStep:colEnd, :);
end
