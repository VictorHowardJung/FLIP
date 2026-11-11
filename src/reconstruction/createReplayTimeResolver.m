function resolve = createReplayTimeResolver(replay)
% Validate a replay clock once and resolve nearest frames by binary search.

    resolveReplayTime(replay, 0);
    time = double(replay.time(:));
    validPose = logical(replay.validPoseData(:));
    frameCount = numel(time);
    resolve = @resolveTime;

    function selection = resolveTime(requestedTime)
        validateattributes(requestedTime, {'numeric'}, {'scalar', 'real', 'finite'});
        requestedTime = double(requestedTime);
        clippedTime = min(max(requestedTime, time(1)), time(end));
        lower = 1;
        upper = frameCount;
        while lower < upper
            middle = floor((lower + upper) / 2);
            if time(middle) < clippedTime
                lower = middle + 1;
            else
                upper = middle;
            end
        end
        candidates = [max(1, lower - 1), lower];
        [distance, nearest] = min(abs(time(candidates) - clippedTime));
        index = candidates(nearest);
        selection = struct('requestedTime', requestedTime, ...
            'clippedTime', clippedTime, 'time', time(index), ...
            'frameIndex', index, 'frameCount', frameCount, ...
            'distance', distance, ...
            'wasClipped', requestedTime < time(1) || requestedTime > time(end), ...
            'validPose', validPose(index), 'poseStatus', "valid");
        if ~validPose(index)
            selection.poseStatus = "gap";
        end
    end
end
