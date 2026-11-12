function response = calculateResponseCharacteristics(time, value, initialValue, finalValue, ...
        onset, settlingThreshold, riseLimits, minimumHold, maxGap)
% Measure response geometry with explicit initial and final output values.
    response = struct('RiseTime', NaN, 'RiseStart', NaN, 'RiseEnd', NaN, ...
        'SettlingTime', NaN, 'SettlingBand', NaN, 'Settled', false, ...
        'Overshoot', NaN, 'PeakTime', NaN, 'PeakAt', NaN, 'PeakValue', NaN);
    amplitude = finalValue - initialValue;
    if numel(time) < 2 || ~isfinite(amplitude) || amplitude == 0
        return;
    end
    t = [onset; time(:)];
    y = [initialValue; value(:)];
    normalized = (y - initialValue) / amplitude;
    response.RiseStart = crossing(t, normalized, riseLimits(1), maxGap);
    response.RiseEnd = crossing(t, normalized, riseLimits(2), maxGap);
    if isfinite(response.RiseStart) && isfinite(response.RiseEnd)
        response.RiseTime = response.RiseEnd - response.RiseStart;
    end
    valid = find(isfinite(normalized));
    [peak, index] = max(normalized(valid));
    peakIndex = valid(index);
    response.Overshoot = max(0, 100 * (peak - 1));
    response.PeakAt = t(peakIndex);
    response.PeakTime = response.PeakAt - onset;
    response.PeakValue = y(peakIndex);
    band = settlingThreshold * abs(amplitude);
    response.SettlingBand = band;
    error = y - finalValue;
    lastOutside = find(isfinite(error) & abs(error) > band, 1, 'last');
    if isempty(lastOutside)
        candidate = onset;
        following = 1:numel(t);
    elseif lastOutside < numel(t) && isfinite(error(lastOutside + 1)) && ...
            t(lastOutside + 1) - t(lastOutside) <= maxGap
        boundary = sign(error(lastOutside)) * band;
        fraction = (boundary - error(lastOutside)) / ...
            (error(lastOutside + 1) - error(lastOutside));
        candidate = t(lastOutside) + fraction * (t(lastOutside + 1) - t(lastOutside));
        following = lastOutside + 1:numel(t);
    else
        return;
    end
    if all(isfinite(error(following))) && all(diff(t(following)) <= maxGap) && ...
            t(end) - candidate + 1e-9 >= minimumHold
        response.SettlingTime = candidate - onset;
        response.Settled = true;
    end
end

function result = crossing(time, value, threshold, maxGap)
    result = NaN;
    for index = 2:numel(time)
        if ~isfinite(value(index - 1)) || ~isfinite(value(index)) || ...
                time(index) - time(index - 1) > maxGap
            return;
        end
        if value(index - 1) < threshold && value(index) >= threshold
            fraction = (threshold - value(index - 1)) / (value(index) - value(index - 1));
            result = time(index - 1) + fraction * (time(index) - time(index - 1));
            return;
        end
    end
end
