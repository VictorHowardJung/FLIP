function intervals = mergeFlightIntervalDefinitions( ...
        intervals, rowIndices, label)
% Merge touching or overlapping selected intervals under one label.

    validateIntervalTable(intervals);
    rowIndices = unique(double(rowIndices(:)));

    if numel(rowIndices) < 2 || any(~isfinite(rowIndices)) || ...
            any(rowIndices ~= round(rowIndices)) || ...
            any(rowIndices < 1) || any(rowIndices > height(intervals))

        error('FLIP:InvalidIntervalSelection', ...
            'Select at least two valid interval rows to merge.');

    end

    selected = sortrows(intervals(rowIndices, :), 'StartTime');
    tolerance = max(1e-9, eps(max(abs([ ...
        selected.StartTime; selected.EndTime]))));

    if any(selected.StartTime(2:end) > ...
            selected.EndTime(1:end-1) + tolerance)

        error('FLIP:NoncontiguousIntervals', ...
            'Only overlapping or directly adjacent intervals can be merged.');

    end

    if nargin < 3 || strlength(strtrim(string(label))) == 0

        label = strjoin(selected.Label, ' + ');

    end

    merged = createFlightIntervalDefinition( ...
        min(selected.StartTime), max(selected.EndTime), label);
    keep = true(height(intervals), 1);
    keep(rowIndices) = false;
    intervals = [intervals(keep, :); merged];
    intervals = sortrows(intervals, {'StartTime', 'EndTime'});

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
