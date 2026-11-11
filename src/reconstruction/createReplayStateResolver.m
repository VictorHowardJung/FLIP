function resolve = createReplayStateResolver(replay)
% Reuse flight-state tables between logged state transitions.

    resolveTime = createReplayTimeResolver(replay);
    cachedState = resolveReplayState(replay, replay.time(1));
    timeline = table();
    if isfield(replay, 'stateTimeline') && istable(replay.stateTimeline)
        timeline = replay.stateTimeline;
    elseif isfield(replay, 'reconstruction') && ...
            isfield(replay.reconstruction, 'stateTimeline') && ...
            istable(replay.reconstruction.stateTimeline)
        timeline = replay.reconstruction.stateTimeline;
    end
    boundaries = zeros(0, 1);
    if ~isempty(timeline)
        boundaries = unique(timeline.Time(isfinite(timeline.Time)));
    end
    cachedInterval = -1;
    resolve = @resolveState;

    function state = resolveState(requestedTime)
        selection = resolveTime(requestedTime);
        lower = 1;
        upper = numel(boundaries);
        interval = 0;
        while lower <= upper
            middle = floor((lower + upper) / 2);
            if boundaries(middle) <= selection.time
                interval = middle;
                lower = middle + 1;
            else
                upper = middle - 1;
            end
        end
        if interval ~= cachedInterval
            cachedState = resolveReplayState(replay, selection.time);
            cachedInterval = interval;
        end
        state = cachedState;
        state.selection = selection;
    end
end
