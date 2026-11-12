function responses = calculateStepResponseMetrics(actualTime, actualValue, ...
        referenceTime, referenceValue, options)
% Measure command-step responses using a qualified steady-tail estimate.

    arguments
        actualTime double
        actualValue double
        referenceTime double
        referenceValue double
        options.Interval (1, 2) double = [-Inf Inf]
        options.SettlingThreshold (1, 1) double {mustBePositive, mustBeFinite} = 0.02
        options.RiseTimeLimits (1, 2) double = [0.1 0.9]
        options.TailFraction (1, 1) double {mustBePositive, mustBeFinite} = 0.2
        options.ReferenceTolerance (1, 1) double {mustBePositive, mustBeFinite} = 0.01
        options.MinimumStepAmplitude (1, 1) double {mustBePositive, mustBeFinite} = 0.05
        options.MinimumPlateauDuration (1, 1) double {mustBePositive, mustBeFinite} = 0.2
        options.MinimumHoldDuration (1, 1) double {mustBePositive, mustBeFinite} = 0.2
        options.MaxSampleGap (1, 1) double = NaN
        options.IsAngle (1, 1) logical = false
    end

    if options.SettlingThreshold >= 1 || options.TailFraction >= 1 || ...
            any(~isfinite(options.RiseTimeLimits)) || ...
            options.RiseTimeLimits(1) <= 0 || options.RiseTimeLimits(2) >= 1 || ...
            options.RiseTimeLimits(1) >= options.RiseTimeLimits(2) || ...
            any(isnan(options.Interval)) || options.Interval(1) >= options.Interval(2) || ...
            (~isnan(options.MaxSampleGap) && ...
            (~isfinite(options.MaxSampleGap) || options.MaxSampleGap <= 0))
        error('FLIP:InvalidResponseOptions', 'Response thresholds and interval bounds are invalid.');
    end
    [time, actual] = prepareSignal(actualTime, actualValue, options.IsAngle);
    [refTime, reference] = prepareSignal(referenceTime, referenceValue, options.IsAngle);
    responses = emptyResponse(options);
    if numel(time) < 2 || numel(refTime) < 2
        responses.Status = "Actual or reference samples unavailable";
        return;
    end
    interval = [max(time(1), options.Interval(1)), min(time(end), options.Interval(2))];
    if interval(1) >= interval(2)
        responses.Status = "No actual samples in the selected interval";
        return;
    end
    actualGap = sampleGap(time, options.MaxSampleGap);
    refGap = sampleGap(refTime, options.MaxSampleGap);
    [starts, stops] = referencePlateaus(refTime, reference, refGap, options.ReferenceTolerance);
    responses = repmat(emptyResponse(options), 0, 1);
    minimumStep = max(options.MinimumStepAmplitude, 5 * options.ReferenceTolerance);

    for index = 2:numel(starts)
        first = starts(index);
        previous = starts(index - 1):stops(index - 1);
        onset = refTime(first);
        if onset < interval(1) || onset >= interval(2) || ...
                stops(index - 1) ~= first - 1 || ...
                refTime(first) - refTime(first - 1) > refGap || ...
                refTime(previous(end)) - refTime(previous(1)) + 1e-9 < options.MinimumPlateauDuration
            continue;
        end
        current = first:stops(index);
        initialTarget = median(reference(previous));
        target = median(reference(current));
        if abs(target - initialTarget) < minimumStep
            continue;
        end
        row = emptyResponse(options);
        row.StepDetected = true;
        row.StepTime = onset;
        row.ResponseStart = onset;
        row.InitialTarget = initialTarget;
        row.Target = target;
        row.CommandStep = target - initialTarget;
        row.WindowStart = onset;
        last = stops(index);
        stopTime = min(interval(2), refTime(last));
        exclusiveEnd = false;
        if last < numel(refTime) && isfinite(reference(last + 1)) && ...
                refTime(last + 1) - refTime(last) <= refGap
            stopTime = min(interval(2), refTime(last + 1));
            exclusiveEnd = stopTime == refTime(last + 1);
        end
        row.WindowEnd = stopTime;
        if refTime(last) - onset + 1e-9 < options.MinimumPlateauDuration
            row.Status = "Target hold too short; select a stable step response";
        else
            row = measureResponse(row, time, actual, actualGap, exclusiveEnd, options);
        end
        responses(end + 1, 1) = row; %#ok<AGROW>
    end

    if isempty(responses)
        row = emptyResponse(options);
        row.WindowStart = interval(1);
        row.WindowEnd = interval(2);
        indices = refTime >= interval(1) & refTime <= interval(2);
        previous = find(refTime <= interval(1), 1, 'last');
        if ~isempty(previous)
            indices(previous) = true;
        end
        values = reference(indices);
        times = refTime(indices);
        if isempty(values) || any(~isfinite(values)) || ...
                refTime(1) > interval(1) || refTime(end) < interval(2) || ...
                any(diff(times) > refGap) || interval(2) - times(end) > refGap || ...
                max(values) - min(values) > 2 * options.ReferenceTolerance
            row.Status = "No isolated step; target varies or reference coverage is incomplete";
        else
            row.Target = median(values);
            row = measureResponse(row, time, actual, actualGap, false, options);
        end
        responses = row;
    end
end

function row = measureResponse(row, time, actual, maxGap, exclusiveEnd, options)
    selected = time >= row.WindowStart & time <= row.WindowEnd;
    if exclusiveEnd
        selected = selected & time < row.WindowEnd;
    end
    t = time(selected);
    y = actual(selected);
    if numel(t) < 3 || t(end) - t(1) + 1e-9 < options.MinimumHoldDuration
        row.Status = "Response window has insufficient samples or duration";
        return;
    end
    if any(~isfinite(y)) || any(diff(t) > maxGap) || ...
            t(1) - row.WindowStart > maxGap || row.WindowEnd - t(end) > maxGap
        row.Status = "Data gap in response window; metrics unavailable";
        return;
    end
    row.WindowEnd = t(end);
    row.DataComplete = true;
    notes = strings(0, 1);
    if row.StepDetected
        before = find(time < row.StepTime, 1, 'last');
        if isempty(before) || ~isfinite(actual(before)) || ...
                t(1) - time(before) > maxGap
            notes(end + 1) = "Pre-step actual unavailable; transient metrics unavailable";
            if options.IsAngle
                y = y + 360 * round((row.Target - y(1)) / 360);
            end
        else
            row.InitialValue = actual(before);
            if options.IsAngle
                shift = 360 * round((row.InitialTarget - row.InitialValue) / 360);
                row.InitialValue = row.InitialValue + shift;
                y = y + shift;
            end
        end
    else
        if options.IsAngle
            y = y + 360 * round((row.Target - y(1)) / 360);
        end
        row.InitialValue = y(1);
        notes(end + 1) = "Constant target; step onset not observed";
    end

    tailStart = t(end) - options.TailFraction * (t(end) - row.WindowStart);
    row.TailStart = tailStart;
    if tailStart < t(1) || t(end) - tailStart + 1e-9 < options.MinimumHoldDuration
        row.Status = "Tail observation too short to estimate a steady output";
        return;
    end
    tail = t > tailStart;
    tailTime = [tailStart; t(tail)];
    tailValue = [interp1(t, y, tailStart, 'linear'); y(tail)];
    duration = tailTime(end) - tailTime(1);
    finalValue = trapz(tailTime, tailValue) / duration;
    error = row.Target - tailValue;
    if options.IsAngle
        error = mod(error + 180, 360) - 180;
    end
    row.TailMeanError = trapz(tailTime, error) / duration;
    tolerance = options.ReferenceTolerance;
    if row.StepDetected && isfinite(row.InitialValue)
        tolerance = max(tolerance, options.SettlingThreshold * abs(finalValue - row.InitialValue));
    end
    if numel(tailValue) < 3 || max(tailValue) - min(tailValue) > tolerance
        row.Status = "Tail is not stable; steady output and classical response metrics unavailable";
        return;
    end
    row.SteadyStateValue = finalValue;
    row.FinalValueEstimated = true;
    row.FinalValueStable = true;
    row.ReferenceStable = true;
    row.SteadyStateError = row.Target - finalValue;
    if options.IsAngle
        row.SteadyStateError = mod(row.SteadyStateError + 180, 360) - 180;
    end
    row.SteadyStateAvailable = true;

    amplitude = finalValue - row.InitialValue;
    if row.StepDetected && isfinite(amplitude) && abs(amplitude) > options.ReferenceTolerance
        geometry = calculateResponseCharacteristics(t, y, row.InitialValue, finalValue, ...
            row.StepTime, options.SettlingThreshold, options.RiseTimeLimits, ...
            options.MinimumHoldDuration, maxGap);
        fields = fieldnames(geometry);
        for index = 1:numel(fields)
            row.(fields{index}) = geometry.(fields{index});
        end
        if ~isfinite(row.RiseTime)
            notes(end + 1) = "Rise thresholds not reached";
        end
        if ~row.Settled
            notes(end + 1) = "Not settled within the observed window";
        end
    elseif row.StepDetected && isfinite(amplitude)
        notes(end + 1) = "Steady output change too small for normalized response metrics";
    end
    if isempty(notes)
        row.Status = "Classical step metrics use the estimated steady output; error = target - output";
    else
        row.Status = strjoin(notes, "; ");
    end
end


function [time, value] = prepareSignal(time, value, isAngle)
    time = time(:);
    value = value(:);
    if numel(time) ~= numel(value)
        error('FLIP:SignalLengthMismatch', 'Each response signal needs matching time and value lengths.');
    end
    finiteTime = isfinite(time);
    time = time(finiteTime);
    value = value(finiteTime);
    if any(diff(time) < 0)
        error('FLIP:NonIncreasingTime', 'Response timestamps must be nondecreasing.');
    end
    [time, indices] = unique(time, 'last');
    value = value(indices);
    if isAngle
        finite = isfinite(value);
        starts = find(finite & [true; ~finite(1:end-1)]);
        stops = find(finite & [~finite(2:end); true]);
        for index = 1:numel(starts)
            run = starts(index):stops(index);
            value(run) = rad2deg(unwrap(deg2rad(value(run))));
        end
    end
end

function gap = sampleGap(time, configuredGap)
    gap = configuredGap;
    if isnan(gap)
        gap = max(0.25, 5 * median(diff(time)));
    end
end

function [starts, stops] = referencePlateaus(time, value, maxGap, tolerance)
    starts = zeros(0, 1);
    stops = zeros(0, 1);
    for index = 1:numel(time)
        if ~isfinite(value(index))
            continue;
        end
        if index == 1 || ~isfinite(value(index - 1)) || ...
                time(index) - time(index - 1) > maxGap || ...
                abs(value(index) - value(starts(end))) > tolerance
            starts(end + 1, 1) = index; %#ok<AGROW>
            stops(end + 1, 1) = index; %#ok<AGROW>
        else
            stops(end) = index;
        end
    end
end

function row = emptyResponse(options)
    row = createControlResponseResult(options.SettlingThreshold, options.TailFraction);
end
