function selection = resolveReplayTime(replay, requestedTime)
% Requested replay time is clipped and snapped to one deterministic frame.

    arguments

        replay (1, 1) struct
        requestedTime (1, 1) double {mustBeFinite}

    end

    validateReplay(replay);

    time = double(replay.time(:));
    clippedTime = min(max(requestedTime, time(1)), time(end));
    [distance, frameIndex] = min(abs(time - clippedTime));

    selection = struct();
    selection.requestedTime = requestedTime;
    selection.clippedTime = clippedTime;
    selection.time = time(frameIndex);
    selection.frameIndex = frameIndex;
    selection.frameCount = numel(time);
    selection.distance = distance;
    selection.wasClipped = requestedTime < time(1) || ...
        requestedTime > time(end);
    selection.validPose = logical(replay.validPoseData(frameIndex));

    if selection.validPose

        selection.poseStatus = "valid";

    else

        selection.poseStatus = "gap";

    end

end


function validateReplay(replay)

    requiredFields = {'time', 'validPoseData'};

    if ~all(isfield(replay, requiredFields))

        error('FLIP:InvalidReplayControlData', ...
            'Replay time and valid-pose data are required.');

    end

    time = double(replay.time(:));
    validPose = replay.validPoseData(:);

    if isempty(time) || numel(validPose) ~= numel(time) || ...
            any(~isfinite(time)) || any(diff(time) <= 0)

        error('FLIP:InvalidReplayControlData', ...
            'Replay time must be finite, increasing, and match validPoseData.');

    end

end
