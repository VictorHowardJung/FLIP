function event = resolveReplayEvent(replay, requestedTime, direction)
% Find the previous or next objective state boundary in replay time.

    arguments

        replay (1, 1) struct
        requestedTime (1, 1) double {mustBeFinite}
        direction (1, 1) string ...
            {mustBeMember(direction, ["previous", "next"])}

    end

    selection = resolveReplayTime(replay, requestedTime);
    timeline = getObjectiveTimeline(replay);
    event = struct( ...
        'found', false, ...
        'time', NaN, ...
        'rows', timeline([] , :), ...
        'summary', "No objective state event in this direction.");

    if isempty(timeline)

        return;

    end

    tolerance = max(eps(max(1, abs(selection.time))) * 8, 1e-12);

    if direction == "previous"

        candidates = timeline.Time < selection.time - tolerance;

        if any(candidates)

            event.time = max(timeline.Time(candidates));

        end

    else

        candidates = timeline.Time > selection.time + tolerance;

        if any(candidates)

            event.time = min(timeline.Time(candidates));

        end

    end

    if ~isfinite(event.time)

        return;

    end

    event.found = true;
    event.rows = timeline(abs(timeline.Time - event.time) <= tolerance, :);
    event.summary = strjoin( ...
        event.rows.Category + ": " + event.rows.State, " | ");

end


function timeline = getObjectiveTimeline(replay)

    timeline = table();

    if isfield(replay, 'stateTimeline') && istable(replay.stateTimeline)

        timeline = replay.stateTimeline;

    elseif isfield(replay, 'reconstruction') && ...
            isfield(replay.reconstruction, 'stateTimeline') && ...
            istable(replay.reconstruction.stateTimeline)

        timeline = replay.reconstruction.stateTimeline;

    end

    if isempty(timeline)

        return;

    end

    required = {'Time', 'Category', 'State'};

    if ~all(ismember(required, timeline.Properties.VariableNames))

        error('FLIP:InvalidReplayStateTimeline', ...
            'The replay state timeline has an invalid schema.');

    end

    objectiveCategories = [ ...
        "Flight mode", "Arming", "Landing", "Ground contact", ...
        "Freefall", "Failsafe", "Failure detector"];
    timeline = timeline( ...
        isfinite(timeline.Time) & ...
        ismember(timeline.Category, objectiveCategories), :);
    timeline = sortrows(timeline, {'Time', 'Category'});

end
