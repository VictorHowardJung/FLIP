function synchronized = synchronizeVectorSignal(actualTime, actualValue, ...
        referenceTime, referenceValue)
% Synchronize vector actual/reference signals on the actual time base within valid segments.

    actualTime = double(actualTime(:));
    actualValue = double(actualValue);
    referenceTime = double(referenceTime(:));
    referenceValue = double(referenceValue);

    if size(actualValue, 1) ~= numel(actualTime) || ...
            size(referenceValue, 1) ~= numel(referenceTime) || ...
            size(actualValue, 2) ~= size(referenceValue, 2)

        error('FLIP:VectorSizeMismatch', ...
            'Actual and reference values must be N-by-D arrays.');

    end

    dimension = size(actualValue, 2);
    synchronized = emptySynchronizedVector(dimension);

    if isempty(actualTime) || isempty(referenceTime) || dimension == 0

        return;

    end

    finiteReferenceTime = isfinite(referenceTime);
    referenceTime = referenceTime(finiteReferenceTime);
    referenceValue = referenceValue(finiteReferenceTime, :);
    [referenceTime, order] = sort(referenceTime);
    referenceValue = referenceValue(order, :);

    if numel(referenceTime) < 2

        return;

    end

    [interpolatedReference, referenceSegment] = ...
        interpolateFiniteVectorSegments( ...
        referenceTime, referenceValue, actualTime);
    validSample = isfinite(actualTime) & ...
        all(isfinite(actualValue), 2) & ...
        all(isfinite(interpolatedReference), 2) & referenceSegment > 0;
    fullSegmentId = createCombinedSegmentIds( ...
        validSample, referenceSegment);

    synchronized.time = actualTime(validSample);
    synchronized.actual = actualValue(validSample, :);
    synchronized.reference = interpolatedReference(validSample, :);
    synchronized.error = synchronized.actual - synchronized.reference;
    synchronized.segmentId = fullSegmentId(validSample);
    synchronized.available = numel(synchronized.time) >= 2;

end


function [interpolated, segmentId] = interpolateFiniteVectorSegments( ...
        referenceTime, referenceValue, queryTime)

    interpolated = NaN(numel(queryTime), size(referenceValue, 2));
    segmentId = zeros(numel(queryTime), 1);
    finiteReference = all(isfinite(referenceValue), 2);
    runStart = finiteReference & [true; ~finiteReference(1:end-1)];
    runNumber = cumsum(runStart);
    validRuns = unique(runNumber(finiteReference), 'stable');
    outputSegment = 0;

    for runIndex = 1:numel(validRuns)

        runMask = finiteReference & runNumber == validRuns(runIndex);
        runTime = referenceTime(runMask);
        runValue = referenceValue(runMask, :);
        [runTime, uniqueIndex] = unique(runTime, 'stable');
        runValue = runValue(uniqueIndex, :);

        if any(diff(runTime) <= 0)

            error('FLIP:NonIncreasingTime', ...
                'Reference timestamps must increase within each segment.');

        end

        if numel(runTime) < 2

            continue;

        end

        queryMask = isfinite(queryTime) & queryTime >= runTime(1) & ...
            queryTime <= runTime(end) & segmentId == 0;

        if ~any(queryMask)

            continue;

        end

        outputSegment = outputSegment + 1;
        interpolated(queryMask, :) = interp1( ...
            runTime, runValue, queryTime(queryMask), 'linear');
        segmentId(queryMask) = outputSegment;

    end

end


function segmentId = createCombinedSegmentIds(validSample, sourceSegment)

    segmentStart = validSample & [true; ...
        ~validSample(1:end-1) | ...
        sourceSegment(1:end-1) ~= sourceSegment(2:end)];
    runningSegment = cumsum(segmentStart);
    segmentId = zeros(size(validSample));
    segmentId(validSample) = runningSegment(validSample);

end


function synchronized = emptySynchronizedVector(dimension)

    synchronized = struct();
    synchronized.available = false;
    synchronized.time = zeros(0, 1);
    synchronized.actual = zeros(0, dimension);
    synchronized.reference = zeros(0, dimension);
    synchronized.error = zeros(0, dimension);
    synchronized.segmentId = zeros(0, 1);
    synchronized.interpolation = 'linear';
    synchronized.timeBase = 'actual signal';

end
