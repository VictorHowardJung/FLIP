function performance = evaluateIntervalControlPerformance(flightData, startTime, endTime, options)
% Evaluate interval tracking and optional detected command-step responses.

    arguments
        flightData (1, 1) struct
        startTime (1, 1) double
        endTime (1, 1) double
        options.SettlingThreshold (1, 1) double {mustBePositive, mustBeFinite} = 0.02
        options.ResponseMode (1, 1) string {mustBeMember(options.ResponseMode, ["selected", "detected"])} = "selected"
        options.TrackingResult (1, 1) struct = struct()
    end

    groups = {'position', 'velocity', 'attitude', 'rates'};
    references = {'positionSetpoint', 'velocitySetpoint', 'attitudeSetpoint', 'ratesSetpoint'};
    fields = {{'x', 'y', 'z'}, {'vx', 'vy', 'vz'}, ...
        {'roll', 'pitch', 'yaw'}, {'roll', 'pitch', 'yaw'}};
    names = ["Position", "Velocity", "Attitude", "Angular rate"];
    axes = {{'X', 'Y', 'Z'}, {'X', 'Y', 'Z'}, ...
        {'Roll', 'Pitch', 'Yaw'}, {'Roll', 'Pitch', 'Yaw'}};
    units = ["m", "m/s", "deg", "deg/s"];
    scales = [1, 1, 180/pi, 180/pi];
    tolerances = [0.01, 0.01, 0.1, 0.5];
    results = cell(12, 1);
    for group = 1:4
        for axis = 1:3
            [time, actual] = signalValues(flightData, groups{group}, fields{group}{axis});
            [refTime, reference] = signalValues(flightData, references{group}, fields{group}{axis});
            if options.ResponseMode == "selected"
                responses = calculateSelectedResponseMetrics(time, actual * scales(group), ...
                    refTime, reference * scales(group), Interval=[startTime endTime], ...
                    SettlingThreshold=options.SettlingThreshold, IsAngle=group == 3, ...
                    ReferenceTolerance=tolerances(group));
            else
                responses = calculateStepResponseMetrics(time, actual * scales(group), ...
                    refTime, reference * scales(group), Interval=[startTime endTime], ...
                    SettlingThreshold=options.SettlingThreshold, IsAngle=group == 3, ...
                    ReferenceTolerance=tolerances(group), MinimumStepAmplitude=5 * tolerances(group));
            end
            rows = struct2table(responses);
            metricField = lower(axes{group}{axis});
            [metrics, synchronized] = trackingMetrics(options.TrackingResult, groups{group}, metricField, ...
                time, actual, refTime, reference, [startTime endTime], scales(group), group == 3);
            rows.IntervalRMSE = repmat(metrics.rmse, height(rows), 1);
            rows.IntervalMAE = repmat(metrics.mae, height(rows), 1);
            rows.IntervalBias = repmat(metrics.meanError, height(rows), 1);
            rows.IntervalMaxAbsError = repmat(metrics.maxAbsoluteError, height(rows), 1);
            rows.IntervalStdDev = repmat(metrics.standardDeviation, height(rows), 1);
            rows.IntervalP95AbsError = repmat(metrics.percentile95AbsoluteError, height(rows), 1);
            rows.IntervalIAE = repmat(metrics.iae, height(rows), 1);
            rows.IntervalISE = repmat(metrics.ise, height(rows), 1);
            rows.IntervalITAE = repmat(metrics.itae, height(rows), 1);
            rows.IntervalValidDuration = repmat(metrics.validDuration, height(rows), 1);
            rows.IntervalSamples = repmat(metrics.sampleCount, height(rows), 1);
            rows.IntervalSegments = repmat(metrics.segmentCount, height(rows), 1);
            [iaeUnit, iseUnit, itaeUnit] = integralUnits(units(group));
            rows.IAEUnit = repmat(iaeUnit, height(rows), 1);
            rows.ISEUnit = repmat(iseUnit, height(rows), 1);
            rows.ITAEUnit = repmat(itaeUnit, height(rows), 1);
            rows.TrackingPeakAt = NaN(height(rows), 1);
            rows.TrackingPeakActual = NaN(height(rows), 1);
            rows.TrackingPeakReference = NaN(height(rows), 1);
            if synchronized.available && ~isempty(synchronized.error)
                [~, peak] = max(abs(synchronized.error));
                rows.TrackingPeakAt(:) = synchronized.time(peak);
                rows.TrackingPeakActual(:) = synchronized.actual(peak);
                rows.TrackingPeakReference(:) = synchronized.actual(peak) - synchronized.error(peak);
            end
            labels = table(repmat(names(group), height(rows), 1), ...
                repmat(string(axes{group}{axis}), height(rows), 1), ...
                repmat(units(group), height(rows), 1), ...
                'VariableNames', {'Signal', 'Axis', 'ValueUnit'});
            results{3 * (group - 1) + axis} = [labels rows];
        end
    end
    performance = struct('summary', vertcat(results{:}), ...
        'responseMode', options.ResponseMode, 'riseTimeLimits', [0.1 0.9], ...
        'settlingThreshold', options.SettlingThreshold, ...
        'tailFraction', 0.2, 'errorDefinition', 'target - actual', ...
        'normalization', 'Only detected-step mode normalizes output response', ...
        'applicability', 'interval tracking evidence; active control mode is not classified');
    fields = {'Signal','Axis','ValueUnit','WindowStart','WindowEnd', ...
        'IntervalRMSE','IntervalMAE','IntervalBias','IntervalMaxAbsError', ...
        'IntervalStdDev','IntervalP95AbsError','IntervalIAE','IAEUnit', ...
        'IntervalISE','ISEUnit','IntervalITAE','ITAEUnit','IntervalValidDuration', ...
        'IntervalSamples','IntervalSegments','TailStart','TailMeanError','Status'};
    performance.trackingSummary = performance.summary(:, fields);
end

function [metrics, synchronized] = trackingMetrics(result, group, field, time, value, refTime, reference, interval, scale, isAngle)
    if isfield(result, group) && isfield(result.(group), field)
        metrics = result.(group).(field).metrics;
        synchronized = result.(group).(field).synchronized;
        return;
    end
    selected = time >= interval(1) & time <= interval(2);
    synchronized = synchronizeSignalPair(time(selected), value(selected), refTime, reference, isAngle);
    synchronized.error = synchronized.error * scale;
    synchronized.actual = synchronized.actual * scale;
    synchronized.reference = synchronized.reference * scale;
    metrics = calculateTrackingMetrics(synchronized);
end

function [iae, ise, itae] = integralUnits(unit)
    switch unit
        case "m/s"
            iae = "m"; ise = "m^2/s"; itae = "m*s";
        case "deg/s"
            iae = "deg"; ise = "deg^2/s"; itae = "deg*s";
        otherwise
            iae = unit + "*s"; ise = unit + "^2*s"; itae = unit + "*s^2";
    end
end

function [time, value] = signalValues(data, name, field)
    time = zeros(0, 1);
    value = zeros(0, 1);
    if isfield(data, name) && isfield(data.(name), 'available') && ...
            data.(name).available && isfield(data.(name), 'time') && isfield(data.(name), field)
        time = double(data.(name).time(:));
        value = double(data.(name).(field)(:));
    end
end
