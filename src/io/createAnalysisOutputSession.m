function session = createAnalysisOutputSession(outputRoot, runDate)
% Reserve dated directories for full-flight and interval analysis outputs.

    arguments
        outputRoot {mustBeTextScalar} = defaultOutputRoot()
        runDate (1, 1) datetime = datetime('today')
    end

    runName = char(string(runDate, 'yyyy-MM-dd'));
    runDirectory = createUniqueOutputDirectory(outputRoot, runName);
    session = struct('runDirectory', runDirectory, ...
        'originalDirectory', fullfile(runDirectory, 'original'), ...
        'intervalDirectory', fullfile(runDirectory, 'intervals'));
    mkdir(session.originalDirectory);
    mkdir(session.intervalDirectory);
end

function outputRoot = defaultOutputRoot()
    projectRoot = fileparts(fileparts(fileparts(mfilename('fullpath'))));
    outputRoot = fullfile(projectRoot, 'results', 'figures');
end
