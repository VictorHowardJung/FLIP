function analysisResult = evaluateTrackingPerformance(flightData)
% Synchronize and evaluate position, velocity, attitude, and angular-rate tracking.

    analysisResult = struct();

    analysisResult.metadata = struct();
    analysisResult.metadata.fileName = flightData.fileName;
    analysisResult.metadata.errorDefinition = 'actual - setpoint';
    analysisResult.metadata.interpolation = 'linear';
    analysisResult.metadata.timeBase = 'actual signal timestamps';
    analysisResult.metadata.metricMethod = ...
        'segment-wise time-weighted trapezoidal integration';
    analysisResult.metadata.applicability = ...
        'raw tracking evidence; active control mode is not yet classified';

    if isfield(flightData, 'stateTimeline') && ...
            istable(flightData.stateTimeline)
        analysisResult.stateTimeline = flightData.stateTimeline;
    else
        analysisResult.stateTimeline = table();
    end

    analysisResult.position.x = evaluateChannel( ...
        flightData.position, flightData.positionSetpoint, ...
        'x', 'x', 1, 'm', false);
    analysisResult.position.y = evaluateChannel( ...
        flightData.position, flightData.positionSetpoint, ...
        'y', 'y', 1, 'm', false);
    analysisResult.position.z = evaluateChannel( ...
        flightData.position, flightData.positionSetpoint, ...
        'z', 'z', 1, 'm', false);

    analysisResult.velocity.x = evaluateChannel( ...
        flightData.velocity, flightData.velocitySetpoint, ...
        'vx', 'vx', 1, 'm/s', false);
    analysisResult.velocity.y = evaluateChannel( ...
        flightData.velocity, flightData.velocitySetpoint, ...
        'vy', 'vy', 1, 'm/s', false);
    analysisResult.velocity.z = evaluateChannel( ...
        flightData.velocity, flightData.velocitySetpoint, ...
        'vz', 'vz', 1, 'm/s', false);

    analysisResult.attitude.roll = evaluateChannel( ...
        flightData.attitude, flightData.attitudeSetpoint, ...
        'roll', 'roll', 180 / pi, 'deg', true);
    analysisResult.attitude.pitch = evaluateChannel( ...
        flightData.attitude, flightData.attitudeSetpoint, ...
        'pitch', 'pitch', 180 / pi, 'deg', true);
    analysisResult.attitude.yaw = evaluateChannel( ...
        flightData.attitude, flightData.attitudeSetpoint, ...
        'yaw', 'yaw', 180 / pi, 'deg', true);

    analysisResult.rates.roll = evaluateChannel( ...
        flightData.rates, flightData.ratesSetpoint, ...
        'roll', 'roll', 180 / pi, 'deg/s', false);
    analysisResult.rates.pitch = evaluateChannel( ...
        flightData.rates, flightData.ratesSetpoint, ...
        'pitch', 'pitch', 180 / pi, 'deg/s', false);
    analysisResult.rates.yaw = evaluateChannel( ...
        flightData.rates, flightData.ratesSetpoint, ...
        'yaw', 'yaw', 180 / pi, 'deg/s', false);

    positionVector = evaluateVectorGroup( ...
        flightData.position, flightData.positionSetpoint, ...
        {'x', 'y', 'z'}, {'x', 'y', 'z'}, 'm');
    analysisResult.spatial.horizontalPosition = ...
        evaluateVectorSubset(positionVector, [1, 2], 'm');
    analysisResult.spatial.position3D = ...
        evaluateVectorSubset(positionVector, [1, 2, 3], 'm');

    velocityVector = evaluateVectorGroup( ...
        flightData.velocity, flightData.velocitySetpoint, ...
        {'vx', 'vy', 'vz'}, {'vx', 'vy', 'vz'}, 'm/s');
    analysisResult.spatial.velocity3D = ...
        evaluateVectorSubset(velocityVector, [1, 2, 3], 'm/s');

    analysisResult.spatial.orientation = ...
        evaluateQuaternionGroup( ...
        flightData.attitude, flightData.attitudeSetpoint);

    analysisResult.summary = buildSummaryTable(analysisResult);
    analysisResult.spatialSummary = buildSpatialSummary(analysisResult);

end


function channel = evaluateChannel(actualSignal, referenceSignal, ...
        actualField, referenceField, scaleFactor, unit, isAngle)

    channel = struct();
    channel.available = false;
    channel.unit = unit;
    channel.synchronized = synchronizeSignalPair([], [], [], [], isAngle);
    channel.metrics = calculateTrackingMetrics(channel.synchronized);
    channel.metrics = attachScalarUnits(channel.metrics, unit);

    if ~isfield(actualSignal, 'available') || ~actualSignal.available || ...
            ~isfield(referenceSignal, 'available') || ...
            ~referenceSignal.available || ...
            ~isfield(actualSignal, actualField) || ...
            ~isfield(referenceSignal, referenceField)

        return;

    end

    synchronized = synchronizeSignalPair( ...
        actualSignal.time, actualSignal.(actualField), ...
        referenceSignal.time, referenceSignal.(referenceField), isAngle);

    synchronized.actual = synchronized.actual .* scaleFactor;
    synchronized.reference = synchronized.reference .* scaleFactor;
    synchronized.error = synchronized.error .* scaleFactor;

    channel.available = synchronized.available;
    channel.synchronized = synchronized;
    channel.metrics = calculateTrackingMetrics(synchronized);
    channel.metrics = attachScalarUnits(channel.metrics, unit);

end


function result = evaluateVectorGroup(actualSignal, referenceSignal, ...
        actualFields, referenceFields, unit)

    result = struct();
    result.available = false;
    result.unit = unit;
    result.synchronized = synchronizeVectorSignal([], zeros(0, 3), ...
        [], zeros(0, 3));

    if ~isfield(actualSignal, 'available') || ~actualSignal.available || ...
            ~isfield(referenceSignal, 'available') || ...
            ~referenceSignal.available || ...
            ~all(isfield(actualSignal, actualFields)) || ...
            ~all(isfield(referenceSignal, referenceFields))

        return;

    end

    actualValue = collectFields(actualSignal, actualFields);
    referenceValue = collectFields(referenceSignal, referenceFields);
    result.synchronized = synchronizeVectorSignal( ...
        actualSignal.time, actualValue, ...
        referenceSignal.time, referenceValue);
    result.available = result.synchronized.available;

end


function result = evaluateVectorSubset(vectorGroup, columns, unit)

    result = struct();
    result.available = vectorGroup.available;
    result.unit = unit;
    result.synchronized = vectorGroup.synchronized;

    if ~vectorGroup.available

        metrics = calculateVectorErrorMetrics([], ...
            zeros(0, numel(columns)), zeros(0, numel(columns)));

    else

        synchronized = vectorGroup.synchronized;
        metrics = calculateVectorErrorMetrics( ...
            synchronized.time, synchronized.actual(:, columns), ...
            synchronized.reference(:, columns), synchronized.segmentId);

    end

    metrics.unit = unit;
    [metrics.iaeUnit, metrics.iseUnit] = integralMetricUnits(unit);
    result.metrics = metrics;

end


function result = evaluateQuaternionGroup(actualSignal, referenceSignal)

    result = struct();
    result.available = false;
    result.unit = 'deg';
    result.synchronized = synchronizeQuaternionSignal( ...
        [], zeros(0, 4), [], zeros(0, 4));
    result.metrics = calculateQuaternionErrorMetrics( ...
        [], zeros(0, 4), zeros(0, 4));

    requiredFields = {'q0', 'q1', 'q2', 'q3'};

    if ~isfield(actualSignal, 'available') || ~actualSignal.available || ...
            ~isfield(referenceSignal, 'available') || ...
            ~referenceSignal.available || ...
            ~all(isfield(actualSignal, requiredFields)) || ...
            ~all(isfield(referenceSignal, requiredFields))

        result.metrics.unit = 'deg';
        return;

    end

    actualQuaternion = collectFields(actualSignal, requiredFields);
    referenceQuaternion = collectFields(referenceSignal, requiredFields);
    synchronized = synchronizeQuaternionSignal( ...
        actualSignal.time, actualQuaternion, ...
        referenceSignal.time, referenceQuaternion);
    metrics = calculateQuaternionErrorMetrics( ...
        synchronized.time, synchronized.actual, synchronized.reference, ...
        synchronized.segmentId);
    angleFields = {'meanAngle', 'rmsAngle', 'maxAngle', ...
        'percentile95Angle'};

    for fieldIndex = 1:numel(angleFields)

        fieldName = angleFields{fieldIndex};
        metrics.(fieldName) = rad2deg(metrics.(fieldName));

    end

    metrics.unit = 'deg';
    result.available = synchronized.available;
    result.synchronized = synchronized;
    result.metrics = metrics;

end


function values = collectFields(signal, fields)

    values = zeros(numel(signal.time), numel(fields));

    for fieldIndex = 1:numel(fields)

        values(:, fieldIndex) = signal.(fields{fieldIndex})(:);

    end

end


function metrics = attachScalarUnits(metrics, unit)

    metrics.unit = unit;
    [metrics.iaeUnit, metrics.iseUnit, metrics.itaeUnit] = integralMetricUnits(unit);

end


function [iaeUnit, iseUnit, itaeUnit] = integralMetricUnits(unit)
% Integral units are U*s, U^2*s, and U*s^2 for IAE, ISE, and ITAE.

    switch unit
        case 'm/s'
            iaeUnit = 'm';
            iseUnit = 'm^2/s';
            itaeUnit = 'm*s';
        case 'deg/s'
            iaeUnit = 'deg';
            iseUnit = 'deg^2/s';
            itaeUnit = 'deg*s';
        otherwise
            iaeUnit = [unit, '*s'];
            iseUnit = [unit, '^2*s'];
            itaeUnit = [unit, '*s^2'];
    end

end


function summary = buildSummaryTable(analysisResult)

    groupNames = [ ...
        repmat("Position", 3, 1); ...
        repmat("Velocity", 3, 1); ...
        repmat("Attitude", 3, 1); ...
        repmat("Angular rate", 3, 1)];

    axisNames = repmat(["X"; "Y"; "Z"], 4, 1);
    channels = { ...
        analysisResult.position.x; ...
        analysisResult.position.y; ...
        analysisResult.position.z; ...
        analysisResult.velocity.x; ...
        analysisResult.velocity.y; ...
        analysisResult.velocity.z; ...
        analysisResult.attitude.roll; ...
        analysisResult.attitude.pitch; ...
        analysisResult.attitude.yaw; ...
        analysisResult.rates.roll; ...
        analysisResult.rates.pitch; ...
        analysisResult.rates.yaw};

    axisNames(7:12) = [ ...
        "Roll"; "Pitch"; "Yaw"; "Roll"; "Pitch"; "Yaw"];

    rowCount = numel(channels);
    available = false(rowCount, 1);
    rmse = NaN(rowCount, 1);
    mae = NaN(rowCount, 1);
    maxAbsoluteError = NaN(rowCount, 1);
    meanError = NaN(rowCount, 1);
    standardDeviation = NaN(rowCount, 1);
    percentile95 = NaN(rowCount, 1);
    iae = NaN(rowCount, 1);
    ise = NaN(rowCount, 1);
    itae = NaN(rowCount, 1);
    unit = strings(rowCount, 1);
    iaeUnit = strings(rowCount, 1);
    iseUnit = strings(rowCount, 1);
    itaeUnit = strings(rowCount, 1);
    sampleCount = zeros(rowCount, 1);
    segmentCount = zeros(rowCount, 1);
    validDuration = zeros(rowCount, 1);
    applicability = strings(rowCount, 1);
    warningText = strings(rowCount, 1);

    for rowIndex = 1:rowCount

        metrics = channels{rowIndex}.metrics;
        available(rowIndex) = metrics.available;
        rmse(rowIndex) = metrics.rmse;
        mae(rowIndex) = metrics.mae;
        maxAbsoluteError(rowIndex) = metrics.maxAbsoluteError;
        meanError(rowIndex) = metrics.meanError;
        standardDeviation(rowIndex) = metrics.standardDeviation;
        percentile95(rowIndex) = metrics.percentile95AbsoluteError;
        iae(rowIndex) = metrics.iae;
        ise(rowIndex) = metrics.ise;
        itae(rowIndex) = metrics.itae;
        unit(rowIndex) = metrics.unit;
        iaeUnit(rowIndex) = metrics.iaeUnit;
        iseUnit(rowIndex) = metrics.iseUnit;
        itaeUnit(rowIndex) = metrics.itaeUnit;
        sampleCount(rowIndex) = metrics.sampleCount;
        segmentCount(rowIndex) = metrics.segmentCount;
        validDuration(rowIndex) = metrics.validDuration;
        applicability(rowIndex) = metrics.applicability;
        warningText(rowIndex) = metrics.warnings;

    end

    summary = table(groupNames, axisNames, available, rmse, mae, ...
        maxAbsoluteError, meanError, standardDeviation, percentile95, ...
        iae, ise, itae, unit, iaeUnit, iseUnit, itaeUnit, sampleCount, ...
        segmentCount, validDuration, applicability, warningText, ...
        'VariableNames', {'Signal', 'Axis', 'Available', 'RMSE', 'MAE', ...
        'MaxAbsError', 'MeanError', 'StdDev', 'P95AbsError', 'IAE', ...
        'ISE', 'ITAE', 'ValueUnit', 'IAEUnit', 'ISEUnit', 'ITAEUnit', ...
        'Samples', 'Segments', 'ValidDuration', 'Applicability', 'Warning'});

end


function summary = buildSpatialSummary(analysisResult)

    metricName = ["Horizontal position"; "3D position"; ...
        "3D velocity"; "Orientation"];
    channels = { ...
        analysisResult.spatial.horizontalPosition; ...
        analysisResult.spatial.position3D; ...
        analysisResult.spatial.velocity3D; ...
        analysisResult.spatial.orientation};
    rowCount = numel(channels);
    available = false(rowCount, 1);
    meanValue = NaN(rowCount, 1);
    rmsValue = NaN(rowCount, 1);
    maxValue = NaN(rowCount, 1);
    percentile95 = NaN(rowCount, 1);
    iae = NaN(rowCount, 1);
    ise = NaN(rowCount, 1);
    valueUnit = strings(rowCount, 1);
    iaeUnit = strings(rowCount, 1);
    iseUnit = strings(rowCount, 1);
    sampleCount = zeros(rowCount, 1);
    segmentCount = zeros(rowCount, 1);
    validDuration = zeros(rowCount, 1);
    applicability = strings(rowCount, 1);
    warningText = strings(rowCount, 1);

    for rowIndex = 1:rowCount

        metrics = channels{rowIndex}.metrics;
        available(rowIndex) = metrics.available;
        sampleCount(rowIndex) = metrics.sampleCount;
        segmentCount(rowIndex) = metrics.segmentCount;
        validDuration(rowIndex) = metrics.validDuration;
        applicability(rowIndex) = metrics.applicability;
        warningText(rowIndex) = metrics.warnings;
        valueUnit(rowIndex) = metrics.unit;

        if rowIndex < 4

            meanValue(rowIndex) = metrics.meanMagnitude;
            rmsValue(rowIndex) = metrics.rmsMagnitude;
            maxValue(rowIndex) = metrics.maxMagnitude;
            percentile95(rowIndex) = metrics.percentile95Magnitude;
            iae(rowIndex) = metrics.iae;
            ise(rowIndex) = metrics.ise;
            iaeUnit(rowIndex) = metrics.iaeUnit;
            iseUnit(rowIndex) = metrics.iseUnit;

        else

            meanValue(rowIndex) = metrics.meanAngle;
            rmsValue(rowIndex) = metrics.rmsAngle;
            maxValue(rowIndex) = metrics.maxAngle;
            percentile95(rowIndex) = metrics.percentile95Angle;

        end

    end

    summary = table(metricName, available, meanValue, rmsValue, maxValue, ...
        percentile95, iae, ise, valueUnit, iaeUnit, iseUnit, sampleCount, ...
        segmentCount, validDuration, applicability, warningText, ...
        'VariableNames', {'Metric', 'Available', 'Mean', 'RMS', 'Maximum', ...
        'P95', 'IAE', 'ISE', 'ValueUnit', 'IAEUnit', 'ISEUnit', 'Samples', ...
        'Segments', 'ValidDuration', 'Applicability', 'Warning'});

end
