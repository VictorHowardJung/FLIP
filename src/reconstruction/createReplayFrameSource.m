function source = createReplayFrameSource(replay)
% Read immutable replay frames on a running simulation clock.

    resolveTime = createReplayTimeResolver(replay);
    anchorIndex = 1;
    anchorTime = NaN;
    warmupFrames = 0;
    actorScale = replay.actorScale.Data;
    source = struct('Seek', @seek, 'Read', @read);

    function seek(requestedTime, warmup)
        selection = resolveTime(requestedTime);
        anchorIndex = selection.frameIndex;
        anchorTime = NaN;
        warmupFrames = warmup;
    end

    function values = read(simulationTime)
        if isnan(anchorTime)
            anchorTime = simulationTime + warmupFrames * replay.sampleTime;
        end
        offset = round((simulationTime - anchorTime) / replay.sampleTime);
        index = min(numel(replay.time), anchorIndex + max(0, offset));
        timestamp = replay.time(index);
        if offset < 0
            timestamp = timestamp + offset * replay.sampleTime;
        end
        values = {replay.translationData(index, :).', ...
            replay.rotationYPRData(index, :).', replay.speedData(index), ...
            replay.altitudeData(index), ...
            reshape(replay.actorTranslationData(index, :, :), 17, 3), ...
            reshape(replay.actorRotationData(index, :, :), 17, 3), ...
            actorScale(:, :, index), timestamp};
    end
end
