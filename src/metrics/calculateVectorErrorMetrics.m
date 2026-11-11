function metrics = calculateVectorErrorMetrics(time, actual, reference, segmentId)
% Calculate position and velocity error-magnitude metrics on a common time base.

    if nargin < 3

        error('FLIP:MissingMetricInput', ...
            'Time, actual vectors, and reference vectors are required.');

    end

    time = double(time(:));
    actual = double(actual);
    reference = double(reference);

    if isscalar(time)

        actual = reshape(actual, 1, []);
        reference = reshape(reference, 1, []);

    end

    if size(actual, 1) ~= numel(time) || ...
            size(reference, 1) ~= numel(time) || ...
            size(actual, 2) ~= size(reference, 2)

        error('FLIP:VectorSizeMismatch', ...
            'Actual and reference vectors must be N-by-D arrays.');

    end

    if nargin < 4

        segmentId = [];

    end

    errorVector = actual - reference;
    magnitude = sqrt(sum(errorVector .^ 2, 2));
    scalar = calculateErrorMetrics(time, magnitude, segmentId);

    metrics = struct();
    metrics.available = scalar.available;
    metrics.sampleCount = scalar.sampleCount;
    metrics.segmentCount = scalar.segmentCount;
    metrics.startTime = scalar.startTime;
    metrics.endTime = scalar.endTime;
    metrics.validDuration = scalar.validDuration;
    metrics.duration = scalar.duration;
    metrics.meanMagnitude = scalar.meanError;
    metrics.rmsMagnitude = scalar.rmse;
    metrics.maxMagnitude = scalar.maxAbsoluteError;
    metrics.percentile95Magnitude = scalar.percentile95AbsoluteError;
    metrics.iae = scalar.iae;
    metrics.ise = scalar.ise;
    metrics.method = scalar.method;
    metrics.percentileMethod = scalar.percentileMethod;
    metrics.applicability = scalar.applicability;
    metrics.unit = '';
    metrics.warnings = scalar.warnings;

end
