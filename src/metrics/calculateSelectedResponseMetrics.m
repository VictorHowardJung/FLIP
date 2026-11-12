function row = calculateSelectedResponseMetrics(actualTime, actualValue, ...
        referenceTime, referenceValue, options)
% Summarize tracking-error observations in the selected interval.
    arguments
        actualTime double
        actualValue double
        referenceTime double
        referenceValue double
        options.Interval (1, 2) double = [-Inf Inf]
        options.SettlingThreshold (1, 1) double {mustBePositive, mustBeFinite} = 0.02
        options.ReferenceTolerance (1, 1) double {mustBePositive, mustBeFinite} = 0.01
        options.IsAngle (1, 1) logical = false
    end
    row = createControlResponseResult(options.SettlingThreshold, 0.2);
    row.AnalysisMode = "Interval tracking";
    if options.SettlingThreshold >= 1 || any(isnan(options.Interval)) || ...
            options.Interval(1) >= options.Interval(2)
        error('FLIP:InvalidResponseOptions', 'Response interval or settling threshold is invalid.');
    end
    [time, actual] = prepareValues(actualTime, actualValue, options.IsAngle);
    [refTime, reference] = prepareValues(referenceTime, referenceValue, options.IsAngle);
    selected = time >= options.Interval(1) & time <= options.Interval(2);
    t = time(selected);
    y = actual(selected);
    if numel(t) < 2
        row.Status = "Actual samples unavailable in the selected interval";
        return;
    end
    maxGap = max(0.25, 5 * median(diff(time)));
    if options.IsAngle && ~isempty(refTime)
        first = find(isfinite(reference) & refTime >= t(1), 1, 'first');
        if ~isempty(first) && isfinite(y(1))
            y = y + 360 * round((reference(first) - y(1)) / 360);
        end
    end
    row.ResponseStart = t(1);
    row.WindowStart = t(1);
    row.WindowEnd = t(end);
    row.InitialValue = y(1);
    row.TailStart = t(end) - 0.2 * (t(end) - t(1));
    row.DataComplete = all(isfinite(y)) && all(diff(t) <= maxGap);
    notes = "Interval tracking over valid actual/reference samples";

    if numel(refTime) >= 2
        synchronized = synchronizeSignalPair(t, y, refTime, reference, false);
        trackingError = -synchronized.error;
        if options.IsAngle
            trackingError = mod(trackingError + 180, 360) - 180;
        end
        [row.TailMeanError, stableError, errorCoverage] = tailMean( ...
            synchronized.time, trackingError, row.TailStart, maxGap, ...
            options.ReferenceTolerance, 0, 0, synchronized.segmentId);
        [row.Target, row.ReferenceStable, ~] = tailMean(synchronized.time, ...
            synchronized.reference, row.TailStart, maxGap, ...
            options.ReferenceTolerance, 0, 0, synchronized.segmentId);
        if ~isempty(synchronized.time)
            row.InitialTarget = synchronized.reference(1);
            row.CommandStep = row.Target - row.InitialTarget;
        end
        tailCovered = ~isempty(synchronized.time) && ...
            t(end) - synchronized.time(end) <= maxGap;
        row.SteadyStateAvailable = stableError && errorCoverage && tailCovered;
        if row.SteadyStateAvailable
            row.SteadyStateError = row.TailMeanError;
        elseif isfinite(row.TailMeanError)
            notes(end + 1) = "Tail mean error available; steady error is not confirmed";
        else
            notes(end + 1) = "Reference coverage unavailable in the final 20%";
        end
    else
        notes(end + 1) = "Reference unavailable; tracking error cannot be calculated";
    end
    if ~row.DataComplete
        notes(end + 1) = "Output contains gaps; valid error segments are integrated separately";
    end
    row.Status = strjoin(notes, "; ");
end

function [meanValue, stable, complete] = tailMean(time, value, start, maxGap, ...
        tolerance, relativeTolerance, initial, segments)
    meanValue = NaN;
    stable = false;
    complete = false;
    if nargin < 8
        newRun = [true; ~isfinite(value(1:end-1)) | ~isfinite(value(2:end)) | diff(time) > maxGap];
        segments = cumsum(newRun);
    end
    kept = time >= start;
    t = time(kept);
    y = value(kept);
    run = segments(kept);
    before = find(time < start, 1, 'last');
    after = find(time >= start, 1, 'first');
    if ~isempty(before) && ~isempty(after) && time(after) > start && ...
            time(after) - time(before) <= maxGap && ...
            segments(before) == segments(after) && all(isfinite(value([before after])))
        y = [interp1(time([before after]), value([before after]), start); y];
        t = [start; t];
        run = [segments(before); run];
    end
    if numel(t) < 2
        return;
    end
    gap = [false; diff(t) > maxGap];
    run = run + cumsum(gap) * (max(run) + 1);
    metrics = calculateErrorMetrics(t, y, run);
    if ~metrics.available
        return;
    end
    meanValue = metrics.meanError;
    complete = all(isfinite(y)) && metrics.segmentCount == 1 && ...
        t(1) - start <= maxGap && all(diff(t) <= maxGap);
    stabilityLimit = max(tolerance, relativeTolerance * abs(meanValue - initial));
    stable = complete && numel(t) >= 3 && t(end) - t(1) + 1e-9 >= 0.2 && ...
        max(y) - min(y) <= stabilityLimit;
end

function [time, value] = prepareValues(time, value, isAngle)
    time = time(:);
    value = value(:);
    if numel(time) ~= numel(value)
        error('FLIP:SignalLengthMismatch', 'Signal time and value lengths must match.');
    end
    selected = isfinite(time);
    time = time(selected);
    value = value(selected);
    if any(diff(time) < 0)
        error('FLIP:NonIncreasingTime', 'Response timestamps must be nondecreasing.');
    end
    [time, indices] = unique(time, 'last');
    value = value(indices);
    if isAngle && ~isempty(value)
        valid = isfinite(value);
        starts = find(valid & [true; ~valid(1:end-1)]);
        stops = find(valid & [~valid(2:end); true]);
        for index = 1:numel(starts)
            run = starts(index):stops(index);
            value(run) = rad2deg(unwrap(deg2rad(value(run))));
        end
    end
end
