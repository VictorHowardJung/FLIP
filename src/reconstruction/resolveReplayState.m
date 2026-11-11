function state = resolveReplayState(replay, requestedTime)
% Resolve the latest objective flight states at one replay time.

    selection = resolveReplayTime(replay, requestedTime);
    categories = [ ...
        "Flight mode", "Arming", "Landing", ...
        "Failsafe", "Failure detector"];
    timeline = getTimeline(replay);
    category = categories(:);
    eventTime = NaN(numel(categories), 1);
    value = NaN(numel(categories), 1);
    label = repmat("Unknown", numel(categories), 1);
    source = repmat("", numel(categories), 1);
    isAlert = false(numel(categories), 1);

    for index = 1:numel(categories)

        rows = find(timeline.Category == categories(index) & ...
            timeline.Time <= selection.time, 1, 'last');

        if isempty(rows)

            continue;

        end

        eventTime(index) = timeline.Time(rows);
        value(index) = timeline.Value(rows);
        label(index) = timeline.State(rows);
        source(index) = timeline.Source(rows);
        isAlert(index) = timeline.IsAlert(rows);

    end

    state = struct();
    state.selection = selection;
    state.table = table(category, label, eventTime, value, source, isAlert, ...
        'VariableNames', ...
        {'Category', 'State', 'EventTime', 'Value', 'Source', 'IsAlert'});
    state.summary = sprintf( ...
        'Mode: %s | %s | %s | Failsafe: %s | Failure: %s', ...
        label(1), label(2), label(3), label(4), label(5));

end


function timeline = getTimeline(replay)

    timeline = table();

    if isfield(replay, 'stateTimeline') && istable(replay.stateTimeline)

        timeline = replay.stateTimeline;

    elseif isfield(replay, 'reconstruction') && ...
            isfield(replay.reconstruction, 'stateTimeline') && ...
            istable(replay.reconstruction.stateTimeline)

        timeline = replay.reconstruction.stateTimeline;

    end

    required = {'Time', 'Category', 'State', 'Value', 'Source', 'IsAlert'};

    if isempty(timeline)

        timeline = table( ...
            zeros(0, 1), strings(0, 1), strings(0, 1), zeros(0, 1), ...
            strings(0, 1), false(0, 1), ...
            'VariableNames', required);
        return;

    end

    if ~all(ismember(required, timeline.Properties.VariableNames))

        error('FLIP:InvalidReplayStateTimeline', ...
            'The replay state timeline has an invalid schema.');

    end

    timeline = timeline(isfinite(timeline.Time), :);
    timeline = sortrows(timeline, {'Time', 'Category'});

end
