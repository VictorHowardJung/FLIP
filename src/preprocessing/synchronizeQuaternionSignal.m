function synchronized = synchronizeQuaternionSignal(actualTime, ...
        actualQuaternion, referenceTime, referenceQuaternion)
% Synchronize actual and reference quaternions using shortest-path SLERP.

    actualTime = double(actualTime(:));
    actualQuaternion = double(actualQuaternion);
    referenceTime = double(referenceTime(:));
    referenceQuaternion = double(referenceQuaternion);

    if size(actualQuaternion, 1) ~= numel(actualTime) || ...
            size(actualQuaternion, 2) ~= 4 || ...
            size(referenceQuaternion, 1) ~= numel(referenceTime) || ...
            size(referenceQuaternion, 2) ~= 4

        error('FLIP:QuaternionSizeMismatch', ...
            'Quaternion signals must be N-by-4 scalar-first arrays.');

    end

    synchronized = emptySynchronizedQuaternion();

    if isempty(actualTime) || isempty(referenceTime)

        return;

    end

    [interpolatedReference, referenceSegment] = ...
        interpolateQuaternionSlerp( ...
        referenceTime, referenceQuaternion, actualTime);
    actualNorm = sqrt(sum(actualQuaternion .^ 2, 2));
    validSample = isfinite(actualTime) & ...
        all(isfinite(actualQuaternion), 2) & actualNorm > 0 & ...
        all(isfinite(interpolatedReference), 2) & referenceSegment > 0;
    fullSegmentId = createCombinedSegmentIds( ...
        validSample, referenceSegment);

    synchronized.time = actualTime(validSample);
    synchronized.actual = actualQuaternion(validSample, :) ./ ...
        actualNorm(validSample);
    synchronized.reference = interpolatedReference(validSample, :);
    synchronized.segmentId = fullSegmentId(validSample);
    synchronized.available = numel(synchronized.time) >= 2;

end


function segmentId = createCombinedSegmentIds(validSample, sourceSegment)

    segmentStart = validSample & [true; ...
        ~validSample(1:end-1) | ...
        sourceSegment(1:end-1) ~= sourceSegment(2:end)];
    runningSegment = cumsum(segmentStart);
    segmentId = zeros(size(validSample));
    segmentId(validSample) = runningSegment(validSample);

end


function synchronized = emptySynchronizedQuaternion()

    synchronized = struct();
    synchronized.available = false;
    synchronized.time = zeros(0, 1);
    synchronized.actual = zeros(0, 4);
    synchronized.reference = zeros(0, 4);
    synchronized.segmentId = zeros(0, 1);
    synchronized.interpolation = 'shortest-path SLERP';
    synchronized.timeBase = 'actual signal';

end
