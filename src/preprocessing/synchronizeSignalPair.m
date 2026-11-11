function synchronized = synchronizeSignalPair(actualTime, actualValue, ...
        referenceTime, referenceValue, isAngle)
% Interpolate references onto actual-signal timestamps within valid segments.

    if nargin < 5

        isAngle = false;

    end

    actualTime = double(actualTime(:));
    actualValue = double(actualValue(:));
    referenceTime = double(referenceTime(:));
    referenceValue = double(referenceValue(:));

    if numel(actualTime) ~= numel(actualValue) || ...
            numel(referenceTime) ~= numel(referenceValue)

        error('FLIP:SignalLengthMismatch', ...
            'Each signal must have the same number of timestamps and values.');

    end

    synchronized = emptySynchronizedSignal();

    validReferenceTime = isfinite(referenceTime);
    referenceTime = referenceTime(validReferenceTime);
    referenceValue = referenceValue(validReferenceTime);

    if numel(referenceTime) < 2 || isempty(actualTime)

        return;

    end

    [referenceTime, order] = sort(referenceTime);
    referenceValue = referenceValue(order);
    [referenceTime, uniqueIndex] = unique(referenceTime, 'stable');
    referenceValue = referenceValue(uniqueIndex);

    if numel(referenceTime) < 2

        return;

    end

    if isAngle

        referenceValue = unwrapFiniteSegments(referenceValue);

    end

    overlapMask = isfinite(actualTime) & ...
        actualTime >= referenceTime(1) & ...
        actualTime <= referenceTime(end);

    queryTime = actualTime(overlapMask);
    queryActual = actualValue(overlapMask);

    if isempty(queryTime)

        return;

    end

    interpolatedReference = interp1(referenceTime, referenceValue, ...
        queryTime, 'linear', NaN);

    validSamples = isfinite(queryActual) & isfinite(interpolatedReference);

    fullSegmentId = createSegmentIds(validSamples);

    synchronized.time = queryTime(validSamples);
    synchronized.actual = queryActual(validSamples);
    synchronized.reference = interpolatedReference(validSamples);
    synchronized.segmentId = fullSegmentId(validSamples);

    if isAngle

        rawError = synchronized.actual - synchronized.reference;
        synchronized.error = atan2(sin(rawError), cos(rawError));

    else

        synchronized.error = ...
            synchronized.actual - synchronized.reference;

    end

    synchronized.available = numel(synchronized.time) >= 2;
    synchronized.interpolation = 'linear';
    synchronized.timeBase = 'actual signal';

end


function synchronized = emptySynchronizedSignal()

    synchronized = struct();
    synchronized.available = false;
    synchronized.time = zeros(0, 1);
    synchronized.actual = zeros(0, 1);
    synchronized.reference = zeros(0, 1);
    synchronized.error = zeros(0, 1);
    synchronized.segmentId = zeros(0, 1);
    synchronized.interpolation = 'linear';
    synchronized.timeBase = 'actual signal';

end


function segmentId = createSegmentIds(validSamples)

    segmentStart = validSamples & [true; ~validSamples(1:end-1)];
    runningSegment = cumsum(segmentStart);
    segmentId = zeros(size(validSamples));
    segmentId(validSamples) = runningSegment(validSamples);

end


function output = unwrapFiniteSegments(input)

    output = input;
    finiteMask = isfinite(input);
    segmentStart = find(finiteMask & [true; ~finiteMask(1:end-1)]);
    segmentEnd = find(finiteMask & [~finiteMask(2:end); true]);

    for segmentIndex = 1:numel(segmentStart)

        indices = segmentStart(segmentIndex):segmentEnd(segmentIndex);
        output(indices) = unwrap(input(indices));

    end

end
