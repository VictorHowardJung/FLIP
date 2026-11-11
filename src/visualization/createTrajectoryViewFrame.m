function viewFrame = createTrajectoryViewFrame(flightData)
% Read logged North-East-Down coordinates for analysis trajectory views.

    requiredFields = {'x', 'y', 'z'};
    if ~isfield(flightData, 'position') || ...
            ~all(isfield(flightData.position, requiredFields))
        error('FLIP:MissingTrajectoryPosition', ...
            'Flight data must contain position x, y, and z signals.');
    end
    north = double(flightData.position.x(:));
    east = double(flightData.position.y(:));
    down = double(flightData.position.z(:));
    sampleCount = numel(north);
    if numel(east) ~= sampleCount || numel(down) ~= sampleCount
        error('FLIP:TrajectoryLengthMismatch', ...
            'Position x, y, and z signals must have the same length.');
    end
    if isfield(flightData.position, 'time') && ...
            numel(flightData.position.time) == sampleCount
        time = double(flightData.position.time(:));
    else
        time = (0:sampleCount-1).';
    end
    valid = isfinite(north) & isfinite(east) & isfinite(down) & isfinite(time);
    if ~any(valid)
        error('FLIP:NoValidTrajectory', ...
            'No finite local-position samples are available for plotting.');
    end
    first = find(valid, 1, 'first');
    last = find(valid, 1, 'last');
    originNED = [north(first), east(first), down(first)];
    north(~valid) = NaN;
    east(~valid) = NaN;
    down(~valid) = NaN;
    viewFrame = struct('time', time, 'north', north, 'east', east, ...
        'down', down, 'validPosition', valid, 'startIndex', first, ...
        'endIndex', last, 'originNED', originNED, 'coordinateFrame', 'NED');
end
