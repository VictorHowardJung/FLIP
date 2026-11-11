function [roll, pitch, yaw] = quaternionToEuler(quaternion)
% Convert Hamilton [w x y z] quaternions to ZYX roll, pitch, and yaw.

    if ~isnumeric(quaternion) || size(quaternion, 2) ~= 4

        error('FLIP:InvalidQuaternionInput', ...
            'Quaternion input must be an N-by-4 numeric array [w x y z].');

    end

    quaternion = double(quaternion);
    sampleCount = size(quaternion, 1);

    roll = NaN(sampleCount, 1);
    pitch = NaN(sampleCount, 1);
    yaw = NaN(sampleCount, 1);

    quaternionNorm = sqrt(sum(quaternion.^2, 2));
    valid = all(isfinite(quaternion), 2) & quaternionNorm > eps;

    if ~any(valid)

        return;

    end

    normalizedQuaternion = quaternion(valid, :) ./ quaternionNorm(valid);

    w = normalizedQuaternion(:, 1);
    x = normalizedQuaternion(:, 2);
    y = normalizedQuaternion(:, 3);
    z = normalizedQuaternion(:, 4);

    roll(valid) = atan2( ...
        2 .* (w .* x + y .* z), ...
        1 - 2 .* (x.^2 + y.^2));

    pitchArgument = 2 .* (w .* y - z .* x);
    pitchArgument = max(-1, min(1, pitchArgument));
    pitch(valid) = asin(pitchArgument);

    yaw(valid) = atan2( ...
        2 .* (w .* z + x .* y), ...
        1 - 2 .* (y.^2 + z.^2));

end
