function replay = prepareSimulinkUnrealReplay(flightData, options)
% Prepare logged poses and velocities as UAV Toolbox Simulink replay inputs.

    arguments

        flightData (1, 1) struct
        options.SampleTime (1, 1) double {mustBeFinite, mustBePositive} = 1 / 60
        options.MaxInterpolationGap (1, 1) double ...
            {mustBeFinite, mustBePositive} = 0.25
        options.VehicleGroundClearance (1, 1) double ...
            {mustBeFinite, mustBeNonnegative} = 0.10
        options.OperatorDistance (1, 1) double ...
            {mustBeFinite, mustBePositive} = 4
        options.OperatorEyeHeight (1, 1) double ...
            {mustBeFinite, mustBePositive} = 1.60
        options.WorldOffset (1, 3) double {mustBeFinite} = [0 0 0]
        options.ViewHeadingDegrees (1, 1) double {mustBeFinite} = 0

    end

    reconstruction = prepareUnrealReconstruction( ...
        flightData, ...
        SampleTime=options.SampleTime, ...
        MaxInterpolationGap=options.MaxInterpolationGap, ...
        PreserveLogDuration=true, ViewHeadingDegrees=options.ViewHeadingDegrees);

    positionFRU = reconstruction.positionFRU;
    rotationRPYView = reconstruction.rotationRPYView;
    rawAltitude = positionFRU(:, 3);
    onGround = prepareGroundState(flightData, reconstruction.sourceTime);
    belowGround = reconstruction.validPose & rawAltitude < 0;
    altitude = max(rawAltitude, 0);
    altitude(onGround & reconstruction.validPose) = 0;
    altitude(~reconstruction.validPose) = NaN;
    translation = convertFRUPositionToUnrealWorld( ...
        positionFRU, altitude, options.VehicleGroundClearance);
    translation = translation + options.WorldOffset;
    rotationYPR = convertFRDAttitudeToUnrealWorld(rotationRPYView);
    [operatorTranslation, operatorRotation] = prepareOperatorView( ...
        translation, altitude, reconstruction.validPose, ...
        options.OperatorDistance, options.OperatorEyeHeight);
    hiddenTranslation = [0 0 -1e6];
    translation(~reconstruction.validPose, :) = ...
        repmat(hiddenTranslation, nnz(~reconstruction.validPose), 1);
    rotationYPR(~reconstruction.validPose, :) = 0;
    [actorTranslation, actorRotation, armed, motorLevel] = ...
        prepareQuadrotorParts(flightData, reconstruction.sourceTime, ...
        translation, rotationYPR);

    replay = struct();
    replay.reconstruction = reconstruction;
    replay.time = reconstruction.sourceTime;
    replay.sampleTime = reconstruction.sampleTime;
    replay.startTime = reconstruction.sourceTime(1);
    replay.stopTime = reconstruction.sourceTime(end);
    replay.translationData = translation;
    replay.positionFRUData = [positionFRU(:, 1:2), altitude];
    replay.rotationYPRData = rotationYPR;
    replay.speedData = reconstruction.speed;
    replay.altitudeData = altitude;
    replay.validPoseData = reconstruction.validPose;
    replay.onGroundData = onGround;
    replay.armedData = armed;
    replay.motorLevelData = motorLevel;
    replay.actorTranslationData = actorTranslation;
    replay.actorRotationData = actorRotation;
    replay.stateTimeline = reconstruction.stateTimeline;
    replay.translation = timeseries( ...
        translation, replay.time, 'Name', 'FLIP Unreal World Translation');
    replay.rotationYPR = timeseries( ...
        rotationYPR, replay.time, 'Name', 'FLIP Rotation YawPitchRoll');
    replay.speed = timeseries( ...
        reconstruction.speed, replay.time, 'Name', 'FLIP Speed');
    replay.altitude = timeseries( ...
        altitude, replay.time, 'Name', 'FLIP Altitude AGL');
    replay.validPose = timeseries( ...
        double(reconstruction.validPose), replay.time, ...
        'Name', 'FLIP Valid Pose');
    replay.armed = timeseries( ...
        double(armed), replay.time, 'Name', 'FLIP Armed State');
    replay.actorTranslation = timeseries( ...
        permute(actorTranslation, [2 3 1]), replay.time, ...
        'Name', 'FLIP Quadrotor Part Translation');
    replay.actorRotation = timeseries( ...
        permute(actorRotation, [2 3 1]), replay.time, ...
        'Name', 'FLIP Quadrotor Part Rotation');
    replay.actorScale = timeseries( ...
        ones(17, 3, numel(replay.time)), replay.time, ...
        'Name', 'FLIP Quadrotor Part Scale');

    firstValid = find(reconstruction.validPose, 1, 'first');
    replay.initialTranslation = translation(firstValid, :);
    replay.initialRotationYPR = rotationYPR(firstValid, :);
    replay.operatorViewTranslation = operatorTranslation;
    replay.operatorViewRotation = operatorRotation;
    replay.metadata = reconstruction.metadata;
    replay.metadata.simulinkTimeReference = ...
        'log-start-relative seconds';
    replay.metadata.translationPortFrame = ...
        'Unreal simulation world ISO 8855: [Forward, -Right, Up]';
    replay.metadata.rotationPortOrder = '[yaw pitch roll] radians';
    replay.metadata.rotationPortFrame = ...
        'Unreal ISO body/world: [-yaw_view, -pitch_FRD, roll_FRD]';
    replay.metadata.invalidPosePolicy = ...
        'move vehicle off-scene; do not bridge gaps';
    replay.metadata.groundReference = ...
        ['first valid local position; land detector grounds the vehicle; ' ...
        'altitude AGL is clamped at zero'];
    replay.metadata.vehicleGroundClearance = ...
        options.VehicleGroundClearance;
    replay.metadata.belowGroundSamplesClamped = nnz(belowGround);
    replay.metadata.groundedSamples = nnz(onGround);
    replay.metadata.cameraView = ...
        'fixed operator viewpoint framed by position bounds, independent of aircraft heading';
    replay.metadata.altitudeDisplayScale = 1;
    replay.metadata.altitudePresentation = ...
        'true metric scale; visibility changed by camera framing only';
    replay.metadata.worldOffset = options.WorldOffset;
    replay.metadata.wallClockPacing = '1 simulation second per real second';
    replay.metadata.propellerPartCount = 17;
    replay.metadata.propellerControl = ...
        ['rotor angle follows actuator_motors while armed; ' ...
        'rotation freezes when actuator_armed becomes false'];

end


function [translationParts, rotationParts, armed, motorLevel] = ...
        prepareQuadrotorParts(flightData, queryTime, bodyTranslation, ...
        bodyRotation)

    sampleCount = numel(queryTime);
    partCount = 17;
    rotorPart = [3 5 7 9];
    rotorDirection = [1 -1 1 -1];
    translationParts = zeros(sampleCount, partCount, 3);
    rotationParts = zeros(sampleCount, partCount, 3);
    translationParts(:, 1, :) = reshape(bodyTranslation, sampleCount, 1, 3);
    rotationParts(:, 1, :) = reshape(bodyRotation, sampleCount, 1, 3);
    motorLevel = prepareMotorLevel(flightData, queryTime);
    armed = prepareArmedState(flightData, queryTime, motorLevel);

    if isempty(motorLevel)

        motorLevel = 0.5 * ones(sampleCount, 4);

    end

    motorLevel(~armed, :) = 0;
    angularSpeed = 25 + 80 * sqrt(max(motorLevel, 0));
    angularSpeed(~armed, :) = 0;
    rotorAngle = zeros(sampleCount, 4);

    for sampleIndex = 2:sampleCount

        timeStep = queryTime(sampleIndex) - queryTime(sampleIndex - 1);
        averageSpeed = 0.5 * ( ...
            angularSpeed(sampleIndex - 1, :) + ...
            angularSpeed(sampleIndex, :));
        rotorAngle(sampleIndex, :) = rotorAngle(sampleIndex - 1, :) + ...
            timeStep * averageSpeed .* rotorDirection;

    end

    for motorIndex = 1:4

        rotationParts(:, rotorPart(motorIndex), 1) = ...
            rotorAngle(:, motorIndex);

    end

end


function motorLevel = prepareMotorLevel(flightData, queryTime)

    motorLevel = [];

    if ~isfield(flightData, 'motorCommand') || ...
            ~isfield(flightData.motorCommand, 'time') || ...
            ~isfield(flightData.motorCommand, 'control')

        return;

    end

    signal = flightData.motorCommand;
    time = double(signal.time(:));
    control = double(signal.control);

    if isempty(time) || size(control, 1) ~= numel(time)

        return;

    end

    channelCount = min(4, size(control, 2));

    if channelCount == 0

        return;

    end

    timeValid = isfinite(time);
    time = time(timeValid);
    control = control(timeValid, 1:channelCount);
    [time, uniqueIndex] = unique(time, 'last');
    control = control(uniqueIndex, :);

    if isempty(time)

        return;

    end

    motorLevel = interp1(time, control, queryTime, 'linear', 0);
    motorLevel(~isfinite(motorLevel)) = 0;
    motorLevel = min(max(abs(motorLevel), 0), 1);

    if channelCount < 4

        motorLevel(:, channelCount + 1:4) = ...
            repmat(mean(motorLevel, 2), 1, 4 - channelCount);

    end

end


function armed = prepareArmedState(flightData, queryTime, motorLevel)

    armed = false(size(queryTime));

    if isfield(flightData, 'armingState') && ...
            isfield(flightData.armingState, 'time') && ...
            isfield(flightData.armingState, 'armed')

        signal = flightData.armingState;
        time = double(signal.time(:));
        state = double(signal.armed(:));
        valid = isfinite(time) & isfinite(state);
        time = time(valid);
        state = state(valid);
        [time, uniqueIndex] = unique(time, 'last');
        state = state(uniqueIndex);

        if ~isempty(time)

            if queryTime(1) < time(1)

                time = [queryTime(1); time];
                state = [state(1); state];

            end

            if queryTime(end) > time(end)

                time = [time; queryTime(end)];
                state = [state; state(end)];

            end

            armed = logical(interp1(time, state, queryTime, 'previous'));
            return;

        end

    end

    if ~isempty(motorLevel)

        armed = any(motorLevel > 0.01, 2);

    end

end


function positionWorld = convertFRUPositionToUnrealWorld( ...
        positionFRU, altitude, groundClearance)

    positionWorld = [ ...
        positionFRU(:, 1), ...
        -positionFRU(:, 2), ...
        altitude + groundClearance];

end


function rotationYPR = convertFRDAttitudeToUnrealWorld(rotationRPYNED)

    roll = rotationRPYNED(:, 1);
    pitch = rotationRPYNED(:, 2);
    yaw = rotationRPYNED(:, 3);
    rotationYPR = [-yaw, -pitch, roll];

end


function onGround = prepareGroundState(flightData, queryTime)

    onGround = false(size(queryTime));

    if ~isfield(flightData, 'landDetection') || ...
            ~isfield(flightData.landDetection, 'time')

        return;

    end

    signal = flightData.landDetection;
    required = {'landed', 'groundContact'};

    if ~all(isfield(signal, required))

        return;

    end

    time = double(signal.time(:));
    grounded = logical(signal.landed(:)) | ...
        logical(signal.groundContact(:));
    valid = isfinite(time);
    time = time(valid);
    grounded = grounded(valid);

    if isempty(time)

        return;

    end

    [time, uniqueIndex] = unique(time, 'last');
    grounded = grounded(uniqueIndex);

    if queryTime(1) < time(1)

        time = [queryTime(1); time];
        grounded = [grounded(1); grounded];

    end

    if queryTime(end) > time(end)

        time = [time; queryTime(end)];
        grounded = [grounded; grounded(end)];

    end

    onGround = logical(interp1( ...
        time, double(grounded), queryTime, 'previous'));

end


function [translation, rotation] = prepareOperatorView( ...
        vehicleTranslation, altitude, validPose, ...
        minimumDistance, eyeHeight)

    horizontalPosition = vehicleTranslation(validPose, 1:2);
    horizontalMinimum = min(horizontalPosition, [], 1);
    horizontalMaximum = max(horizontalPosition, [], 1);
    trajectoryCenter = (horizontalMinimum + horizontalMaximum) / 2;
    horizontalSpan = norm(horizontalMaximum - horizontalMinimum);
    distance = max(minimumDistance, 1.05 * horizontalSpan);
    cameraHorizontal = [horizontalMinimum(1) - distance, trajectoryCenter(2)];
    validAltitude = altitude(validPose);
    targetAltitude = (min(validAltitude) + max(validAltitude)) / 2;
    targetAltitude = max(0.5, targetAltitude);
    targetVector = [ ...
        trajectoryCenter - cameraHorizontal, ...
        targetAltitude - eyeHeight];
    horizontalRange = norm(targetVector(1:2));
    cameraYaw = atan2(targetVector(2), targetVector(1));
    cameraPitch = atan2(targetVector(3), horizontalRange);

    translation = [cameraHorizontal, eyeHeight];
    rotation = rad2deg([0, cameraPitch, cameraYaw]);

end
