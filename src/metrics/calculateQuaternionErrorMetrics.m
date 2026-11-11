function metrics = calculateQuaternionErrorMetrics(time, actualQuaternion, ...
        referenceQuaternion, segmentId)
% Calculate shortest-rotation error metrics between unit quaternions.

    if nargin < 3

        error('FLIP:MissingMetricInput', ...
            'Time, actual quaternions, and reference quaternions are required.');

    end

    time = double(time(:));
    actualQuaternion = double(actualQuaternion);
    referenceQuaternion = double(referenceQuaternion);

    if size(actualQuaternion, 1) ~= numel(time) || ...
            size(referenceQuaternion, 1) ~= numel(time) || ...
            size(actualQuaternion, 2) ~= 4 || ...
            size(referenceQuaternion, 2) ~= 4

        error('FLIP:QuaternionSizeMismatch', ...
            'Quaternion inputs must be N-by-4 scalar-first arrays.');

    end

    if nargin < 4

        segmentId = [];

    end

    [actualQuaternion, actualValid] = normalizeQuaternionRows( ...
        actualQuaternion);
    [referenceQuaternion, referenceValid] = normalizeQuaternionRows( ...
        referenceQuaternion);
    valid = actualValid & referenceValid;
    dotProduct = sum(actualQuaternion .* referenceQuaternion, 2);
    dotProduct = min(max(abs(dotProduct), 0), 1);
    angle = 2 * acos(dotProduct);
    angle(~valid) = NaN;

    scalar = calculateErrorMetrics(time, angle, segmentId);

    metrics = struct();
    metrics.available = scalar.available;
    metrics.sampleCount = scalar.sampleCount;
    metrics.segmentCount = scalar.segmentCount;
    metrics.startTime = scalar.startTime;
    metrics.endTime = scalar.endTime;
    metrics.validDuration = scalar.validDuration;
    metrics.duration = scalar.duration;
    metrics.meanAngle = scalar.meanError;
    metrics.rmsAngle = scalar.rmse;
    metrics.maxAngle = scalar.maxAbsoluteError;
    metrics.percentile95Angle = scalar.percentile95AbsoluteError;
    metrics.method = [scalar.method, '; shortest quaternion rotation angle'];
    metrics.percentileMethod = scalar.percentileMethod;
    metrics.applicability = scalar.applicability;
    metrics.unit = 'rad';
    metrics.warnings = scalar.warnings;

end


function [quaternion, valid] = normalizeQuaternionRows(quaternion)

    rowNorm = sqrt(sum(quaternion .^ 2, 2));
    valid = all(isfinite(quaternion), 2) & isfinite(rowNorm) & rowNorm > 0;
    quaternion(valid, :) = quaternion(valid, :) ./ rowNorm(valid);
    quaternion(~valid, :) = NaN;

end
