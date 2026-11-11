function metrics = calculateErrorMetrics(time, errorValue, segmentId)
% Calculate time-weighted scalar error metrics separately within valid segments.

    if nargin < 2

        error('FLIP:MissingMetricInput', ...
            'Time and error values are required.');

    end

    time = double(time(:));
    errorValue = double(errorValue(:));

    if numel(time) ~= numel(errorValue)

        error('FLIP:SignalLengthMismatch', ...
            'Time and error must contain the same number of samples.');

    end

    if nargin < 3 || isempty(segmentId)

        segmentId = ones(size(time));

    else

        segmentId = double(segmentId(:));

        if numel(segmentId) ~= numel(time)

            error('FLIP:SegmentLengthMismatch', ...
                'Segment IDs must match the number of time samples.');

        end

    end

    metrics = emptyErrorMetrics();
    finiteSample = isfinite(time) & isfinite(errorValue) & ...
        isfinite(segmentId) & segmentId > 0;

    if ~any(finiteSample)

        return;

    end

    finiteTime = time(finiteSample);

    if any(diff(finiteTime) < 0)

        error('FLIP:NonIncreasingTime', ...
            'Finite timestamps must be in nondecreasing order.');

    end

    runStart = finiteSample & [true; ...
        ~finiteSample(1:end-1) | ...
        segmentId(1:end-1) ~= segmentId(2:end)];
    runNumber = cumsum(runStart);
    validRunNumbers = unique(runNumber(finiteSample), 'stable');

    segmentTimes = cell(0, 1);
    segmentErrors = cell(0, 1);
    ignoredSingletonCount = 0;

    for runIndex = 1:numel(validRunNumbers)

        runMask = finiteSample & runNumber == validRunNumbers(runIndex);
        runTime = time(runMask);
        runError = errorValue(runMask);
        [runTime, uniqueIndex] = unique(runTime, 'stable');
        runError = runError(uniqueIndex);

        if any(diff(runTime) <= 0)

            error('FLIP:NonIncreasingTime', ...
                'Timestamps within each finite segment must increase.');

        end

        if numel(runTime) < 2

            ignoredSingletonCount = ignoredSingletonCount + 1;
            continue;

        end

        segmentTimes{end + 1, 1} = runTime; %#ok<AGROW>
        segmentErrors{end + 1, 1} = runError; %#ok<AGROW>

    end

    if isempty(segmentTimes)

        metrics.warnings = "No finite segment contains at least two samples.";
        return;

    end

    evaluationStart = min(cellfun(@(value) value(1), segmentTimes));
    validDuration = 0;
    signedIntegral = 0;
    absoluteIntegral = 0;
    squareIntegral = 0;
    timeAbsoluteIntegral = 0;
    allErrors = zeros(0, 1);
    allAbsoluteErrors = zeros(0, 1);
    allWeights = zeros(0, 1);

    for segmentIndex = 1:numel(segmentTimes)

        segmentTime = segmentTimes{segmentIndex};
        segmentError = segmentErrors{segmentIndex};
        segmentDuration = segmentTime(end) - segmentTime(1);
        elapsedTime = segmentTime - evaluationStart;

        validDuration = validDuration + segmentDuration;
        signedIntegral = signedIntegral + ...
            trapz(segmentTime, segmentError);
        absoluteIntegral = absoluteIntegral + ...
            trapz(segmentTime, abs(segmentError));
        squareIntegral = squareIntegral + ...
            trapz(segmentTime, segmentError .^ 2);
        timeAbsoluteIntegral = timeAbsoluteIntegral + ...
            trapz(segmentTime, elapsedTime .* abs(segmentError));

        allErrors = [allErrors; segmentError]; %#ok<AGROW>
        allAbsoluteErrors = [allAbsoluteErrors; abs(segmentError)]; %#ok<AGROW>
        allWeights = [allWeights; sampleTimeWeights(segmentTime)]; %#ok<AGROW>

    end

    if validDuration <= 0

        return;

    end

    meanError = signedIntegral / validDuration;
    varianceIntegral = 0;

    for segmentIndex = 1:numel(segmentTimes)

        varianceIntegral = varianceIntegral + trapz( ...
            segmentTimes{segmentIndex}, ...
            (segmentErrors{segmentIndex} - meanError) .^ 2);

    end

    metrics.available = true;
    metrics.sampleCount = numel(allErrors);
    metrics.segmentCount = numel(segmentTimes);
    metrics.startTime = min(cellfun(@(value) value(1), segmentTimes));
    metrics.endTime = max(cellfun(@(value) value(end), segmentTimes));
    metrics.validDuration = validDuration;
    metrics.duration = validDuration;
    metrics.meanError = meanError;
    metrics.mae = absoluteIntegral / validDuration;
    metrics.rmse = sqrt(squareIntegral / validDuration);
    metrics.maxAbsoluteError = max(allAbsoluteErrors);
    metrics.standardDeviation = sqrt(varianceIntegral / validDuration);
    metrics.percentile95AbsoluteError = weightedPercentile( ...
        allAbsoluteErrors, allWeights, 0.95);
    metrics.iae = absoluteIntegral;
    metrics.ise = squareIntegral;
    metrics.itae = timeAbsoluteIntegral;

    if ignoredSingletonCount > 0

        metrics.warnings = sprintf( ...
            '%d singleton segment(s) were excluded from integration.', ...
            ignoredSingletonCount);

    end

end


function weights = sampleTimeWeights(time)

    interval = diff(time);
    weights = zeros(size(time));
    weights(1) = interval(1) / 2;
    weights(end) = interval(end) / 2;

    if numel(time) > 2

        weights(2:end-1) = (time(3:end) - time(1:end-2)) / 2;

    end

end


function value = weightedPercentile(data, weights, probability)

    [sortedData, order] = sort(data);
    sortedWeights = weights(order);
    threshold = probability * sum(sortedWeights);
    index = find(cumsum(sortedWeights) >= threshold, 1, 'first');
    value = sortedData(index);

end


function metrics = emptyErrorMetrics()

    metrics = struct();
    metrics.available = false;
    metrics.sampleCount = 0;
    metrics.segmentCount = 0;
    metrics.startTime = NaN;
    metrics.endTime = NaN;
    metrics.validDuration = 0;
    metrics.duration = 0;
    metrics.meanError = NaN;
    metrics.mae = NaN;
    metrics.rmse = NaN;
    metrics.maxAbsoluteError = NaN;
    metrics.standardDeviation = NaN;
    metrics.percentile95AbsoluteError = NaN;
    metrics.iae = NaN;
    metrics.ise = NaN;
    metrics.itae = NaN;
    metrics.method = ...
        'segment-wise time-weighted trapezoidal integration';
    metrics.percentileMethod = 'weighted empirical inverse CDF';
    metrics.applicability = 'raw';
    metrics.unit = '';
    metrics.warnings = "";

end
