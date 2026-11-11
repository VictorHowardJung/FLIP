function interval = createFlightIntervalDefinition(startTime, endTime, label)
% Create a consistently structured table row for a user-defined flight interval.

    if nargin < 3 || isempty(label)

        label = 'Selected interval';

    end

    [startTime, endTime, label] = validateDefinition( ...
        startTime, endTime, label);
    interval = table(string(label), startTime, endTime, ...
        endTime - startTime, 'VariableNames', ...
        {'Label', 'StartTime', 'EndTime', 'Duration'});

end


function [startTime, endTime, label] = validateDefinition( ...
        startTime, endTime, label)

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

    if ~(ischar(label) || (isstring(label) && isscalar(label)))

        error('FLIP:InvalidIntervalLabel', ...
            'The interval label must be text.');

    end

    label = char(strtrim(string(label)));

    if isempty(label)

        label = 'Selected interval';

    end

end
