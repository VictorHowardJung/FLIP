function reconstruction = prepareUnrealReconstruction(flightData, options)
% Resample preprocessed flight logs into fixed-step Unreal pose data.

    arguments

        flightData (1, 1) struct
        options.SampleTime (1, 1) double {mustBeFinite, mustBePositive} = 1 / 60
        options.MaxInterpolationGap (1, 1) double ...
            {mustBeFinite, mustBePositive} = 0.25
        options.PreserveLogDuration (1, 1) logical = false
        options.ViewHeadingDegrees (1, 1) double {mustBeFinite} = 0

    end

    validateFlightData(flightData);

    positionTime = double(flightData.position.time(:));
    positionNED = double([ ...
        flightData.position.x(:), ...
        flightData.position.y(:), ...
        flightData.position.z(:)]);
    attitudeTime = double(flightData.attitude.time(:));
    attitudeQuaternion = double([ ...
        flightData.attitude.q0(:), ...
        flightData.attitude.q1(:), ...
        flightData.attitude.q2(:), ...
        flightData.attitude.q3(:)]);

    validateSignalTime(positionTime, positionNED, 'position');
    validateSignalTime(attitudeTime, attitudeQuaternion, 'attitude');

    validPosition = isfinite(positionTime) & ...
        all(isfinite(positionNED), 2);
    quaternionNorm = sqrt(sum(attitudeQuaternion .^ 2, 2));
    validAttitude = isfinite(attitudeTime) & ...
        all(isfinite(attitudeQuaternion), 2) & quaternionNorm > eps;

    if nnz(validPosition) < 2 || nnz(validAttitude) < 2

        error('FLIP:InsufficientUnrealPoseData', [ ...
            'At least two finite position and attitude samples are ' ...
            'required for Unreal reconstruction.']);

    end

    if options.PreserveLogDuration

        [sourceStart, sourceEnd] = getRequestedTimeBounds(flightData);
        [positionTime, positionNED] = extendSignalToBounds( ...
            positionTime, positionNED, sourceStart, sourceEnd, ...
            options.MaxInterpolationGap);
        [attitudeTime, attitudeQuaternion] = extendSignalToBounds( ...
            attitudeTime, attitudeQuaternion, sourceStart, sourceEnd, ...
            options.MaxInterpolationGap);

    else

        sourceStart = max(positionTime(find(validPosition, 1, 'first')), ...
            attitudeTime(find(validAttitude, 1, 'first')));
        sourceEnd = min(positionTime(find(validPosition, 1, 'last')), ...
            attitudeTime(find(validAttitude, 1, 'last')));

    end

    if sourceEnd - sourceStart < options.SampleTime

        error('FLIP:InsufficientUnrealOverlap', [ ...
            'Position and attitude signals do not have enough overlapping ' ...
            'time for the requested Unreal sample time.']);

    end

    playbackDuration = sourceEnd - sourceStart;
    frameCount = max(1, floor(playbackDuration / options.SampleTime));
    actualSampleTime = playbackDuration / frameCount;
    playbackTime = linspace(0, playbackDuration, frameCount + 1).';
    sourceTime = sourceStart + playbackTime;

    [interpolatedPosition, positionSegment] = ...
        interpolateFiniteRuns(positionTime, positionNED, sourceTime, ...
        options.MaxInterpolationGap, 'position');
    [interpolatedQuaternion, attitudeSegment] = ...
        interpolateQuaternionRuns(attitudeTime, attitudeQuaternion, ...
        sourceTime, options.MaxInterpolationGap);

    validPose = positionSegment > 0 & attitudeSegment > 0 & ...
        all(isfinite(interpolatedPosition), 2) & ...
        all(isfinite(interpolatedQuaternion), 2);

    if nnz(validPose) < 2

        error('FLIP:InsufficientUnrealPoseData', [ ...
            'Fewer than two synchronized finite poses remain after gap-aware ' ...
            'interpolation.']);

    end

    firstValid = find(validPose, 1, 'first');
    originNED = interpolatedPosition(firstValid, :);
    relativePositionNED = interpolatedPosition - originNED;
    relativePositionNED(~validPose, :) = NaN;

    [roll, pitch, yaw] = quaternionToEuler(interpolatedQuaternion);
    rotationRPY = [roll, pitch, yaw];
    rotationRPY(~validPose, :) = NaN;
    referenceYaw = deg2rad(options.ViewHeadingDegrees);
    forward = cos(referenceYaw) * relativePositionNED(:, 1) + ...
        sin(referenceYaw) * relativePositionNED(:, 2);
    right = -sin(referenceYaw) * relativePositionNED(:, 1) + ...
        cos(referenceYaw) * relativePositionNED(:, 2);
    positionFRU = [forward, right, -relativePositionNED(:, 3)];
    rotationRPYView = rotationRPY;
    rotationRPYView(:, 3) = atan2( ...
        sin(yaw - referenceYaw), cos(yaw - referenceYaw));
    rotationRPYView(~validPose, :) = NaN;
    poseSegment = combinePoseSegments( ...
        validPose, positionSegment, attitudeSegment);
    [velocityNED, validVelocity] = prepareVelocity( ...
        flightData, sourceTime, options.MaxInterpolationGap, ...
        options.PreserveLogDuration);
    speed = sqrt(sum(velocityNED .^ 2, 2));
    speed(~validVelocity) = NaN;

    reconstruction = struct();
    reconstruction.sourceTime = sourceTime;
    reconstruction.playbackTime = playbackTime;
    reconstruction.sampleTime = actualSampleTime;
    reconstruction.positionNED = relativePositionNED;
    reconstruction.positionFRU = positionFRU;
    reconstruction.quaternionWXYZ = interpolatedQuaternion;
    reconstruction.rotationRPY = rotationRPY;
    reconstruction.rotationRPYView = rotationRPYView;
    reconstruction.referenceYaw = referenceYaw;
    reconstruction.velocityNED = velocityNED;
    reconstruction.speed = speed;
    reconstruction.validPose = validPose;
    reconstruction.validVelocity = validVelocity;
    reconstruction.segmentId = poseSegment;
    reconstruction.originNED = originNED;
    reconstruction.stateTimeline = getStateTimeline(flightData);

    reconstruction.metadata = struct();
    reconstruction.metadata.sourceFile = getSourceFile(flightData);
    reconstruction.metadata.sourceStartTime = sourceStart;
    reconstruction.metadata.sourceEndTime = sourceTime(end);
    reconstruction.metadata.sampleTime = actualSampleTime;
    reconstruction.metadata.requestedSampleTime = options.SampleTime;
    reconstruction.metadata.preserveLogDuration = ...
        options.PreserveLogDuration;
    reconstruction.metadata.maxInterpolationGap = ...
        options.MaxInterpolationGap;
    reconstruction.metadata.coordinateSystem = ...
        'AERO: local NED position and FRD body attitude';
    reconstruction.metadata.presentationFrame = ...
        'Fixed operator FRU: first valid position, configured view heading, local vertical';
    reconstruction.metadata.referenceYawDegrees = rad2deg(referenceYaw);
    reconstruction.metadata.positionInterpolation = ...
        'linear within finite contiguous segments';
    reconstruction.metadata.attitudeInterpolation = ...
        'normalized shortest-path quaternion SLERP';
    reconstruction.metadata.velocitySource = ...
        'vehicle_local_position vx, vy, vz when available';
    reconstruction.metadata.provenance = ...
        'Log-derived reconstruction; not camera ground truth';

end


function [velocityNED, validVelocity] = prepareVelocity( ...
        flightData, sourceTime, maxGap, preserveLogDuration)

    velocityNED = NaN(numel(sourceTime), 3);
    validVelocity = false(numel(sourceTime), 1);
    requiredVelocity = {'time', 'vx', 'vy', 'vz'};

    if ~isfield(flightData, 'velocity') || ...
            ~all(isfield(flightData.velocity, requiredVelocity))

        return;

    end

    velocityTime = double(flightData.velocity.time(:));
    sourceVelocity = double([ ...
        flightData.velocity.vx(:), ...
        flightData.velocity.vy(:), ...
        flightData.velocity.vz(:)]);
    validateSignalTime(velocityTime, sourceVelocity, 'velocity');

    if preserveLogDuration

        [velocityTime, sourceVelocity] = extendSignalToBounds( ...
            velocityTime, sourceVelocity, sourceTime(1), sourceTime(end), ...
            maxGap);

    end
    finiteVelocity = isfinite(velocityTime) & ...
        all(isfinite(sourceVelocity), 2);

    if nnz(finiteVelocity) < 2

        return;

    end

    try

        [velocityNED, velocitySegment] = interpolateFiniteRuns( ...
            velocityTime, sourceVelocity, sourceTime, maxGap, 'velocity');

    catch exception

        if strcmp(exception.identifier, 'FLIP:NoInterpolatedUnrealSignal')

            return;

        end

        rethrow(exception);

    end
    validVelocity = velocitySegment > 0 & all(isfinite(velocityNED), 2);
    velocityNED(~validVelocity, :) = NaN;

end


function [startTime, endTime] = getRequestedTimeBounds(flightData)

    metadata = flightData.metadata;

    if isfield(metadata, 'analysisInterval') && ...
            isfield(metadata.analysisInterval, 'requestedStartTime') && ...
            isfield(metadata.analysisInterval, 'requestedEndTime')

        startTime = double(metadata.analysisInterval.requestedStartTime);
        endTime = double(metadata.analysisInterval.requestedEndTime);

    elseif all(isfield(metadata, {'logStartTime', 'logEndTime'}))

        startTime = double(metadata.logStartTime);
        endTime = double(metadata.logEndTime);

    else

        error('FLIP:MissingUnrealTimeBounds', [ ...
            'Preserving flight duration requires logStartTime and ' ...
            'logEndTime metadata.']);

    end

    if ~isfinite(startTime) || ~isfinite(endTime) || startTime >= endTime

        error('FLIP:InvalidUnrealTimeBounds', ...
            'The requested Unreal replay time range is invalid.');

    end

end


function [time, value] = extendSignalToBounds( ...
        time, value, startTime, endTime, maxGap)

    valid = isfinite(time) & all(isfinite(value), 2);
    firstValid = find(valid, 1, 'first');
    lastValid = find(valid, 1, 'last');

    if isempty(firstValid) || isempty(lastValid)

        return;

    end

    firstTime = time(firstValid);
    firstValue = value(firstValid, :);
    lastTime = time(lastValid);
    lastValue = value(lastValid, :);

    if firstTime > startTime && firstTime - startTime <= maxGap

        time = [startTime; time];
        value = [firstValue; value];

    end

    if lastTime < endTime && endTime - lastTime <= maxGap

        time = [time; endTime];
        value = [value; lastValue];

    end

end


function validateFlightData(flightData)

    if ~isfield(flightData, 'metadata') || ...
            ~isfield(flightData.metadata, 'timeNormalized') || ...
            ~flightData.metadata.timeNormalized

        error('FLIP:UnnormalizedUnrealFlightData', [ ...
            'Run preprocessFlightData before preparing Unreal ' ...
            'reconstruction data.']);

    end

    requiredPosition = {'time', 'x', 'y', 'z'};
    requiredAttitude = {'time', 'q0', 'q1', 'q2', 'q3'};

    if ~isfield(flightData, 'position') || ...
            ~all(isfield(flightData.position, requiredPosition))

        error('FLIP:MissingUnrealPosition', ...
            'Position time, x, y, and z are required for Unreal playback.');

    end

    if ~isfield(flightData, 'attitude') || ...
            ~all(isfield(flightData.attitude, requiredAttitude))

        error('FLIP:MissingUnrealAttitude', ...
            'Attitude time and q0-q3 are required for Unreal playback.');

    end

end


function validateSignalTime(time, value, signalName)

    if size(value, 1) ~= numel(time)

        error('FLIP:UnrealSignalLengthMismatch', ...
            '%s time and data lengths must match.', signalName);

    end

    finiteTime = time(isfinite(time));

    if any(diff(finiteTime) <= 0)

        error('FLIP:NonIncreasingUnrealTime', ...
            '%s timestamps must increase strictly.', signalName);

    end

end


function [interpolated, segmentId] = interpolateFiniteRuns( ...
        referenceTime, referenceValue, queryTime, maxGap, signalName)

    validReference = isfinite(referenceTime) & ...
        all(isfinite(referenceValue), 2);
    referenceSegment = identifySourceSegments( ...
        referenceTime, validReference, maxGap);
    interpolated = NaN(numel(queryTime), size(referenceValue, 2));
    segmentId = zeros(numel(queryTime), 1);
    outputSegment = 0;

    for sourceSegment = reshape(unique( ...
            referenceSegment(referenceSegment > 0), 'stable'), 1, [])

        sourceMask = referenceSegment == sourceSegment;
        runTime = referenceTime(sourceMask);
        runValue = referenceValue(sourceMask, :);

        if numel(runTime) < 2

            continue;

        end

        queryMask = queryTime >= runTime(1) & queryTime <= runTime(end) & ...
            segmentId == 0;

        if ~any(queryMask)

            continue;

        end

        outputSegment = outputSegment + 1;
        interpolated(queryMask, :) = interp1( ...
            runTime, runValue, queryTime(queryMask), 'linear');
        segmentId(queryMask) = outputSegment;

    end

    if ~any(segmentId > 0)

        error('FLIP:NoInterpolatedUnrealSignal', ...
            'No valid %s segment overlaps the Unreal time base.', signalName);

    end

end


function [interpolated, segmentId] = interpolateQuaternionRuns( ...
        referenceTime, referenceQuaternion, queryTime, maxGap)

    quaternionNorm = sqrt(sum(referenceQuaternion .^ 2, 2));
    validReference = isfinite(referenceTime) & ...
        all(isfinite(referenceQuaternion), 2) & quaternionNorm > eps;
    referenceSegment = identifySourceSegments( ...
        referenceTime, validReference, maxGap);
    interpolated = NaN(numel(queryTime), 4);
    segmentId = zeros(numel(queryTime), 1);
    outputSegment = 0;

    for sourceSegment = reshape(unique( ...
            referenceSegment(referenceSegment > 0), 'stable'), 1, [])

        sourceMask = referenceSegment == sourceSegment;
        runTime = referenceTime(sourceMask);
        runQuaternion = referenceQuaternion(sourceMask, :);

        if numel(runTime) < 2

            continue;

        end

        queryMask = queryTime >= runTime(1) & queryTime <= runTime(end) & ...
            segmentId == 0;

        if ~any(queryMask)

            continue;

        end

        outputSegment = outputSegment + 1;
        [interpolated(queryMask, :), ignoredSegment] = ...
            interpolateQuaternionSlerp( ...
            runTime, runQuaternion, queryTime(queryMask)); %#ok<ASGLU>
        segmentId(queryMask) = outputSegment;

    end

    if ~any(segmentId > 0)

        error('FLIP:NoInterpolatedUnrealSignal', ...
            'No valid attitude segment overlaps the Unreal time base.');

    end

end


function segmentId = identifySourceSegments(time, valid, maxGap)

    segmentId = zeros(size(time));
    currentSegment = 0;

    for index = 1:numel(time)

        if ~valid(index)

            continue;

        end

        startsSegment = index == 1 || ~valid(index - 1) || ...
            time(index) - time(index - 1) > maxGap;

        if startsSegment

            currentSegment = currentSegment + 1;

        end

        segmentId(index) = currentSegment;

    end

end


function segmentId = combinePoseSegments( ...
        validPose, positionSegment, attitudeSegment)

    segmentStart = validPose & [true; ...
        ~validPose(1:end-1) | ...
        positionSegment(1:end-1) ~= positionSegment(2:end) | ...
        attitudeSegment(1:end-1) ~= attitudeSegment(2:end)];
    runningSegment = cumsum(segmentStart);
    segmentId = zeros(size(validPose));
    segmentId(validPose) = runningSegment(validPose);

end


function timeline = getStateTimeline(flightData)

    if isfield(flightData, 'stateTimeline') && ...
            istable(flightData.stateTimeline)

        timeline = flightData.stateTimeline;

    else

        timeline = table();

    end

end


function sourceFile = getSourceFile(flightData)

    sourceFile = '';

    if isfield(flightData, 'fileName')

        sourceFile = char(string(flightData.fileName));

    end

end
