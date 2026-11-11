function camera = fitReplayCameraIntrinsics(replay)
% Limit extra optical magnification using logged pose and mesh bounds.

    imageSize = [1080 1920];
    baseFocalLength = 960;
    yaw = deg2rad(replay.operatorViewRotation(3));
    pitch = deg2rad(replay.operatorViewRotation(2));
    forward = [cos(pitch)*cos(yaw), cos(pitch)*sin(yaw), sin(pitch)];
    right = [sin(yaw), -cos(yaw), 0];
    up = cross(right, forward);
    relative = replay.translationData(replay.validPoseData, :) - ...
        replay.operatorViewTranslation;
    depth = relative * forward.';
    horizontal = relative * right.';
    vertical = relative * up.';
    meshRadius = 0.5;
    horizontalLimit = 0.45 * imageSize(2) * ...
        (depth - meshRadius) ./ (abs(horizontal) + meshRadius);
    verticalLimit = 0.42 * imageSize(1) * ...
        (depth - meshRadius) ./ (abs(vertical) + meshRadius);
    fittedFocalLength = min([horizontalLimit; verticalLimit]);
    focalLength = max(baseFocalLength, min(2.5 * baseFocalLength, fittedFocalLength));
    camera = struct('imageSize', imageSize, ...
        'focalLength', [focalLength focalLength], ...
        'opticalCenter', [imageSize(2) imageSize(1)] / 2, ...
        'opticalZoom', focalLength / baseFocalLength);
end
