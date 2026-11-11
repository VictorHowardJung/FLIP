function flightData = loadTLog(logFile, options)
% Read common-dialect MAVLink telemetry using UAV Toolbox.

    arguments
        logFile {mustBeTextScalar}
        options.SystemID (1, 1) double = NaN
        options.ComponentID (1, 1) double = NaN
    end

    logFile = char(logFile);
    if ~isfile(logFile)
        error('FLIP:FileNotFound', 'The selected TLOG does not exist:\n%s', logFile);
    end
    [~, ~, extension] = fileparts(logFile);
    if ~strcmpi(extension, '.tlog')
        error('FLIP:InvalidFileExtension', 'A .tlog file is required.');
    end
    if isempty(which('mavlinktlog')) || ~license('test', 'UAV_Toolbox')
        error('FLIP:MissingUAVToolbox', ...
            'A licensed UAV Toolbox with mavlinktlog is required.');
    end

    try
        reader = mavlinktlog(logFile, mavlinkdialect('common.xml'));
    catch exception
        error('FLIP:TLogReadFailed', 'Could not read TLOG:\n%s\n%s', ...
            logFile, exception.message);
    end
    if reader.NumMessages == 0
        error('FLIP:EmptyTLog', 'The TLOG contains no recognized MAVLink packets.');
    end

    names = string(reader.AvailableTopics.MessageName);
    coreNames = ["ATTITUDE", "ATTITUDE_QUATERNION", ...
        "LOCAL_POSITION_NED", "GLOBAL_POSITION_INT", "GPS_RAW_INT", ...
        "POSITION_TARGET_LOCAL_NED", "ATTITUDE_TARGET"];
    selectedNames = unique(names(ismember(names, coreNames)));
    if isempty(selectedNames)
        error('FLIP:MissingTLogPose', ...
            'No supported position or attitude messages are present in this TLOG.');
    end
    messages = readmsg(reader, 'MessageName', cellstr(selectedNames));
    metadata = struct('sourceFile', logFile, ...
        'recordingStartTime', reader.StartTime, ...
        'recordingEndTime', reader.EndTime);
    flightData = convertTLogMessages(messages, metadata, ...
        SystemID=options.SystemID, ComponentID=options.ComponentID);

    % The catalog includes topics outside the analysis schema.
    topics = reader.AvailableTopics;
    count = height(topics);
    catalog = table(names, double(topics.ComponentID), NaN(count, 1), ...
        NaN(count, 1), double(topics.NumMessages), false(count, 1), ...
        repmat("not_yet_supported", count, 1), double(topics.SystemID), ...
        'VariableNames', {'TopicName', 'InstanceID', 'StartTime', ...
        'EndTime', 'SampleCount', 'Supported', 'Category', 'SystemID'});
    coreCatalog = flightData.catalog;
    for index = 1:height(coreCatalog)
        match = catalog.TopicName == coreCatalog.TopicName(index) & ...
            catalog.InstanceID == coreCatalog.InstanceID(index) & ...
            catalog.SystemID == coreCatalog.SystemID(index);
        catalog.StartTime(match) = coreCatalog.StartTime(index);
        catalog.EndTime(match) = coreCatalog.EndTime(index);
        catalog.Supported(match) = coreCatalog.Supported(index);
        catalog.Category(match) = coreCatalog.Category(index);
    end
    flightData.catalog = catalog;
    flightData.metadata.topicCount = height(catalog);
    flightData.metadata.supportedTopicCount = nnz(catalog.Supported);
    flightData.metadata.numPacketsLost = reader.NumPacketsLost;
end
