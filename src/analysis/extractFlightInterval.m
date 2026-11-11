function intervalData = extractFlightInterval(flightData, startTime, ...
        endTime, label)
% Extract an interval from preprocessed flight data using log-relative time.

    if nargin < 3

        error('FLIP:MissingIntervalInput', ...
            'Flight data, start time, and end time are required.');

    end

    if nargin < 4 || isempty(label)

        label = 'Selected interval';

    end

    validateFlightData(flightData);
    [startTime, endTime, label] = validateInterval( ...
        flightData, startTime, endTime, label);

    intervalData = flightData;
    signalNames = fieldnames(intervalData);

    for signalIndex = 1:numel(signalNames)

        signalName = signalNames{signalIndex};
        signal = intervalData.(signalName);

        if isstruct(signal) && isscalar(signal) && ...
                isfield(signal, 'time') && isnumeric(signal.time)

            intervalData.(signalName) = sliceTimedSignal( ...
                signal, startTime, endTime);

        end

    end

    if isfield(intervalData, 'stateTimeline') && ...
            istable(intervalData.stateTimeline)

        intervalData.stateTimeline = sliceStateTimeline( ...
            intervalData.stateTimeline, startTime, endTime);

    end

    positionTime = intervalData.position.time(:);

    if numel(positionTime) < 2

        error('FLIP:IntervalTooShort', [ ...
            'The selected interval must contain at least two local-position ' ...
            'samples. Choose a longer interval.']);

    end

    intervalData.metadata.analysisScope = 'interval';
    timeReference = 'ULog start';
    if isfield(flightData.metadata, 'timeReference')
        timeReference = flightData.metadata.timeReference;
    end
    intervalData.metadata.analysisInterval = struct( ...
        'label', label, ...
        'requestedStartTime', startTime, ...
        'requestedEndTime', endTime, ...
        'effectiveStartTime', positionTime(1), ...
        'effectiveEndTime', positionTime(end), ...
        'duration', endTime - startTime, ...
        'timeReference', timeReference);

end


function timeline = sliceStateTimeline(timeline, startTime, endTime)

    if isempty(timeline) || ...
            ~all(ismember({'Time', 'Category'}, ...
            timeline.Properties.VariableNames))

        return;

    end

    if ~ismember('IsInherited', timeline.Properties.VariableNames)

        timeline.IsInherited = false(height(timeline), 1);

    end

    categories = unique(timeline.Category, 'stable');
    selected = timeline([] , :);

    for categoryIndex = 1:numel(categories)

        categoryRows = timeline( ...
            timeline.Category == categories(categoryIndex), :);
        categoryRows = sortrows(categoryRows, 'Time');
        inInterval = categoryRows.Time >= startTime & ...
            categoryRows.Time <= endTime;
        currentRows = categoryRows(inInterval, :);

        if ~any(categoryRows.Time == startTime)

            priorIndex = find(categoryRows.Time < startTime, 1, 'last');

            if ~isempty(priorIndex)

                inheritedRow = categoryRows(priorIndex, :);
                inheritedRow.Time = startTime;
                inheritedRow.IsInherited = true;
                currentRows = [inheritedRow; currentRows]; %#ok<AGROW>

            end

        end

        selected = [selected; currentRows]; %#ok<AGROW>

    end

    timeline = sortrows(selected, {'Time', 'Category'});

end


function validateFlightData(flightData)

    if ~isstruct(flightData) || ~isscalar(flightData) || ...
            ~isfield(flightData, 'metadata') || ...
            ~isfield(flightData, 'position') || ...
            ~isfield(flightData.position, 'time')

        error('FLIP:InvalidFlightData', ...
            'Preprocessed FLIP flight data is required.');

    end

    if ~isfield(flightData.metadata, 'timeNormalized') || ...
            ~flightData.metadata.timeNormalized

        error('FLIP:IntervalRequiresNormalizedTime', ...
            'Normalize flight time before selecting an interval.');

    end

end


function [startTime, endTime, label] = validateInterval( ...
        flightData, startTime, endTime, label)

    if ~(isnumeric(startTime) && isscalar(startTime) && ...
            isfinite(startTime)) || ...
            ~(isnumeric(endTime) && isscalar(endTime) && isfinite(endTime))

        error('FLIP:InvalidIntervalTime', ...
            'Interval start and end times must be finite numeric scalars.');

    end

    startTime = double(startTime);
    endTime = double(endTime);

    if startTime >= endTime

        error('FLIP:InvalidIntervalOrder', ...
            'Interval end time must be greater than start time.');

    end

    finitePositionTime = flightData.position.time( ...
        isfinite(flightData.position.time));

    if isempty(finitePositionTime)

        error('FLIP:NoValidTrajectory', ...
            'No finite local-position timestamps are available.');

    end

    availableStart = min(finitePositionTime);
    availableEnd = max(finitePositionTime);

    if startTime < availableStart || endTime > availableEnd

        error('FLIP:IntervalOutsideFlight', [ ...
            'Choose an interval within the available trajectory range ' ...
            '[%.3f, %.3f] seconds.'], availableStart, availableEnd);

    end

    if ~(ischar(label) || (isstring(label) && isscalar(label)))

        error('FLIP:InvalidIntervalLabel', ...
            'The interval label must be text.');

    end

    label = char(strtrim(string(label)));

    if isempty(label)

        label = 'Selected interval';

    end

end


function signal = sliceTimedSignal(signal, startTime, endTime)

    time = signal.time(:);
    sampleCount = numel(time);
    keep = isfinite(time) & time >= startTime & time <= endTime;
    fields = fieldnames(signal);

    for fieldIndex = 1:numel(fields)

        fieldName = fields{fieldIndex};
        value = signal.(fieldName);

        if isSampleArray(value, sampleCount, fieldName)

            if size(value, 1) == sampleCount

                signal.(fieldName) = value(keep, :);

            else

                signal.(fieldName) = value(:, keep);

            end

        end

    end

    signal.intervalSampleCount = sum(keep);
    signal.availableInInterval = any(keep);

end


function result = isSampleArray(value, sampleCount, fieldName)

    metadataFields = {'available', 'topicName', 'instanceID', ...
        'intervalSampleCount', 'availableInInterval'};

    result = ~ismember(fieldName, metadataFields) && sampleCount > 0 && ...
        (isnumeric(value) || islogical(value) || isduration(value) || ...
        isdatetime(value) || iscategorical(value) || isstring(value) || ...
        iscell(value)) && ...
        ((size(value, 1) == sampleCount) || ...
        (isvector(value) && size(value, 2) == sampleCount));

end
