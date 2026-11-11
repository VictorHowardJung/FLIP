function flightData = loadFlightLog(logFile, varargin)
% Read a supported flight log into the common FLIP signal structure.

    if nargin < 1 || isempty(logFile)
        error('FLIP:MissingLogFile', 'A flight-log file path is required.');
    end
    if ~(ischar(logFile) && isrow(logFile)) && ...
            ~(isstring(logFile) && isscalar(logFile) && ~ismissing(logFile))
        error('FLIP:InvalidLogFilePath', 'The flight-log path must be text.');
    end
    logFile = char(logFile);
    if ~isfile(logFile)
        error('FLIP:FileNotFound', 'The selected log does not exist:\n%s', logFile);
    end
    [~, ~, extension] = fileparts(logFile);
    switch lower(extension)
        case '.ulg'
            flightData = loadULog(logFile);
        case '.tlog'
            flightData = loadTLog(logFile, varargin{:});
        otherwise
            error('FLIP:InvalidFileExtension', ...
                'Supported flight-log extensions are .ulg and .tlog.');
    end
end
