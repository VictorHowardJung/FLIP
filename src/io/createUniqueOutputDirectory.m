function outputDirectory = createUniqueOutputDirectory(outputRoot, name)
% Create a numbered output directory without reusing an existing path.

    arguments
        outputRoot {mustBeTextScalar}
        name {mustBeTextScalar}
    end

    outputRoot = char(outputRoot);
    name = char(name);
    if isempty(name) || any(strcmp(name, {'.', '..'})) || ...
            contains(name, '/') || contains(name, '\')
        error('FLIP:InvalidOutputDirectoryName', ...
            'The output directory name must be a single nonempty folder name.');
    end

    index = 1;
    while true
        candidateName = name;
        if index > 1
            candidateName = sprintf('%s_%03d', name, index);
        end
        outputDirectory = fullfile(outputRoot, candidateName);
        if ~isfolder(outputDirectory) && ~isfile(outputDirectory)
            [created, message, messageId] = mkdir(outputDirectory);
            if ~created
                error('FLIP:OutputDirectoryCreationFailed', '%s', message);
            end
            if isempty(messageId)
                return;
            end
        end
        index = index + 1;
    end
end
