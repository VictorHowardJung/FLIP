function intervals = splitFlightIntervalDefinition( ...
        intervals, rowIndex, splitTime)
% Split a selected flight interval into two labeled intervals at the requested time.

    validateIntervalTable(intervals);

    if ~(isnumeric(rowIndex) && isscalar(rowIndex) && ...
            isfinite(rowIndex) && rowIndex == round(rowIndex) && ...
            rowIndex >= 1 && rowIndex <= height(intervals))

        error('FLIP:InvalidIntervalSelection', ...
            'Select one valid interval row to split.');

    end

    if ~(isnumeric(splitTime) && isscalar(splitTime) && ...
            isfinite(splitTime))

        error('FLIP:InvalidIntervalTime', ...
            'The split time must be a finite numeric scalar.');

    end

    selected = intervals(rowIndex, :);

    if splitTime <= selected.StartTime || splitTime >= selected.EndTime

        error('FLIP:SplitOutsideInterval', ...
            'Split time must lie strictly inside the selected interval.');

    end

    left = createFlightIntervalDefinition(selected.StartTime, ...
        splitTime, selected.Label + " A");
    right = createFlightIntervalDefinition(splitTime, ...
        selected.EndTime, selected.Label + " B");
    intervals = [intervals(1:(rowIndex - 1), :); left; right; ...
        intervals((rowIndex + 1):end, :)];

end


function validateIntervalTable(intervals)

    requiredVariables = {'Label', 'StartTime', 'EndTime', 'Duration'};

    if ~istable(intervals) || ...
            ~all(ismember(requiredVariables, ...
            intervals.Properties.VariableNames))

        error('FLIP:InvalidIntervalTable', ...
            'A FLIP interval definition table is required.');

    end

end
