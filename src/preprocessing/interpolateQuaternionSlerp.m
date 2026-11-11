function [interpolated, segmentId] = interpolateQuaternionSlerp( ...
        referenceTime, referenceQuaternion, queryTime)
% Interpolate quaternion references using shortest-path SLERP without crossing gaps.

    referenceTime = double(referenceTime(:));
    referenceQuaternion = double(referenceQuaternion);
    queryTime = double(queryTime(:));

    if size(referenceQuaternion, 1) ~= numel(referenceTime) || ...
            size(referenceQuaternion, 2) ~= 4

        error('FLIP:QuaternionSizeMismatch', ...
            'Reference quaternions must be an N-by-4 array.');

    end

    interpolated = NaN(numel(queryTime), 4);
    segmentId = zeros(numel(queryTime), 1);
    referenceNorm = sqrt(sum(referenceQuaternion .^ 2, 2));
    finiteReference = isfinite(referenceTime) & ...
        all(isfinite(referenceQuaternion), 2) & referenceNorm > 0;
    referenceQuaternion(finiteReference, :) = ...
        referenceQuaternion(finiteReference, :) ./ ...
        referenceNorm(finiteReference);

    runStart = finiteReference & [true; ~finiteReference(1:end-1)];
    runNumber = cumsum(runStart);
    validRuns = unique(runNumber(finiteReference), 'stable');
    outputSegment = 0;

    for runIndex = 1:numel(validRuns)

        runMask = finiteReference & runNumber == validRuns(runIndex);
        runTime = referenceTime(runMask);
        runQuaternion = referenceQuaternion(runMask, :);
        [runTime, uniqueIndex] = unique(runTime, 'stable');
        runQuaternion = runQuaternion(uniqueIndex, :);

        if any(diff(runTime) <= 0)

            error('FLIP:NonIncreasingTime', ...
                'Quaternion reference timestamps must increase.');

        end

        if numel(runTime) < 2

            continue;

        end

        queryMask = isfinite(queryTime) & queryTime >= runTime(1) & ...
            queryTime <= runTime(end) & segmentId == 0;
        queryIndices = find(queryMask);

        if isempty(queryIndices)

            continue;

        end

        outputSegment = outputSegment + 1;

        for queryIndex = reshape(queryIndices, 1, [])

            timeValue = queryTime(queryIndex);

            if timeValue == runTime(end)

                lowerIndex = numel(runTime) - 1;
                alpha = 1;

            else

                lowerIndex = find(runTime <= timeValue, 1, 'last');
                alpha = (timeValue - runTime(lowerIndex)) / ...
                    (runTime(lowerIndex + 1) - runTime(lowerIndex));

            end

            interpolated(queryIndex, :) = slerpPair( ...
                runQuaternion(lowerIndex, :), ...
                runQuaternion(lowerIndex + 1, :), alpha);
            segmentId(queryIndex) = outputSegment;

        end

    end

end


function output = slerpPair(first, second, alpha)

    dotProduct = sum(first .* second);

    if dotProduct < 0

        second = -second;
        dotProduct = -dotProduct;

    end

    dotProduct = min(max(dotProduct, -1), 1);

    if dotProduct > 1 - 1e-12

        output = (1 - alpha) .* first + alpha .* second;

    else

        angle = acos(dotProduct);
        output = sin((1 - alpha) * angle) / sin(angle) .* first + ...
            sin(alpha * angle) / sin(angle) .* second;

    end

    output = output ./ sqrt(sum(output .^ 2));

end
