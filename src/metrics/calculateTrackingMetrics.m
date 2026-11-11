function metrics = calculateTrackingMetrics(synchronized)
% Calculate tracking metrics for synchronized signal errors.

    if ~isfield(synchronized, 'time') || ...
            ~isfield(synchronized, 'error')

        metrics = calculateErrorMetrics([], []);
        return;

    end

    if isfield(synchronized, 'segmentId')

        segmentId = synchronized.segmentId;

    else

        segmentId = [];

    end

    metrics = calculateErrorMetrics( ...
        synchronized.time, synchronized.error, segmentId);

end
