function flightData = convertTLogMessages(messages, metadata, options)
% Convert decoded MAVLink payloads to FLIP signals in SI units and NED coordinates.
% Packet recording time is the common time reference.
% GPS-only positions use an approximate local NED frame at the first valid fix.

    arguments
        messages table
        metadata (1, 1) struct
        options.SystemID (1, 1) double = NaN
        options.ComponentID (1, 1) double = NaN
    end

    required = {'MessageName', 'SystemID', 'ComponentID', 'Messages'};
    if ~all(ismember(required, messages.Properties.VariableNames)) || ...
            ~all(isfield(metadata, ...
            {'sourceFile', 'recordingStartTime', 'recordingEndTime'}))
        error('FLIP:InvalidTLogMessages', 'Decoded TLOG messages and recording bounds are required.');
    end
    validateID(options.SystemID);
    validateID(options.ComponentID);
    [systemID, componentID] = selectVehicle(messages, options);
    messages = messages(double(messages.SystemID) == systemID & ...
        double(messages.ComponentID) == componentID, :);
    origin = metadata.recordingStartTime;
    durationSeconds = seconds(metadata.recordingEndTime - origin);
    if ~isscalar(durationSeconds) || ~isfinite(durationSeconds) || durationSeconds <= 0
        error('FLIP:InvalidTLogTime', 'TLOG recording bounds must span a positive duration.');
    end

    [~, name, extension] = fileparts(metadata.sourceFile);
    flightData = struct('fileName', [name extension]);
    metadata.backend = 'MATLAB UAV Toolbox';
    metadata.logFormat = 'MAVLink TLOG';
    metadata.timeUnit = 'seconds';
    metadata.logStartTime = 0;
    metadata.logEndTime = durationSeconds;
    metadata.dropoutIntervals = zeros(0, 2);
    metadata.timeReference = 'TLOG start';
    metadata.timestampReference = 'TLOG recording start; original times in recordedTime';
    metadata.systemID = systemID;
    metadata.componentID = componentID;
    metadata.coordinateFrame = 'NED';
    metadata.missingDataPolicy = 'Unlogged signals remain unavailable; no synthetic setpoints';
    flightData.metadata = metadata;

    definitions = { ...
        'position', {'x', 'y', 'z'}; ...
        'velocity', {'vx', 'vy', 'vz'}; ...
        'attitude', {'q0', 'q1', 'q2', 'q3'}; ...
        'rates', {'roll', 'pitch', 'yaw'}; ...
        'positionSetpoint', {'x', 'y', 'z', 'yaw'}; ...
        'velocitySetpoint', {'vx', 'vy', 'vz', 'yawSpeed'}; ...
        'attitudeSetpoint', {'q0', 'q1', 'q2', 'q3'}; ...
        'ratesSetpoint', {'roll', 'pitch', 'yaw'}};
    for index = 1:size(definitions, 1)
        flightData.(definitions{index, 1}) = emptySignal(definitions{index, 2});
    end

    attitude = payload(messages, 'ATTITUDE_QUATERNION');
    if ~isempty(attitude)
        flightData.attitude = signal(attitude, origin, 'ATTITUDE_QUATERNION', ...
            {'q0', 'q1', 'q2', 'q3'}, columns(attitude, {'q1', 'q2', 'q3', 'q4'}), componentID);
    else
        attitude = payload(messages, 'ATTITUDE');
        if isempty(attitude)
            error('FLIP:MissingTLogPose', 'ATTITUDE or ATTITUDE_QUATERNION messages are required.');
        end
        q = eulerQuaternion(columns(attitude, {'roll', 'pitch', 'yaw'}));
        flightData.attitude = signal(attitude, origin, 'ATTITUDE', ...
            {'q0', 'q1', 'q2', 'q3'}, q, componentID);
    end
    flightData.rates = signal(attitude, origin, flightData.attitude.topicName, ...
        {'roll', 'pitch', 'yaw'}, columns(attitude, ...
        {'rollspeed', 'pitchspeed', 'yawspeed'}), componentID);

    local = payload(messages, 'LOCAL_POSITION_NED');
    globalPosition = payload(messages, 'GLOBAL_POSITION_INT');
    gps = payload(messages, 'GPS_RAW_INT');
    if ~isempty(local)
        flightData.position = signal(local, origin, 'LOCAL_POSITION_NED', ...
            {'x', 'y', 'z'}, columns(local, {'x', 'y', 'z'}), componentID);
        flightData.velocity = signal(local, origin, 'LOCAL_POSITION_NED', ...
            {'vx', 'vy', 'vz'}, columns(local, {'vx', 'vy', 'vz'}), componentID);
        flightData.metadata.positionConversion = 'Logged LOCAL_POSITION_NED in metres';
        if ~isempty(globalPosition) && any(validGeographicRows(globalPosition, false))
            geographic = geographicPosition(flightData, globalPosition, origin, ...
                'GLOBAL_POSITION_INT', componentID, false);
            flightData.geographicPosition = geographic.geographicPosition;
        elseif ~isempty(gps) && any(validGeographicRows(gps, true))
            geographic = geographicPosition(flightData, gps, origin, ...
                'GPS_RAW_INT', componentID, true);
            flightData.geographicPosition = geographic.geographicPosition;
        end
    elseif ~isempty(globalPosition) && any(validGeographicRows(globalPosition, false))
        flightData = geographicPosition(flightData, globalPosition, origin, ...
            'GLOBAL_POSITION_INT', componentID, false);
        flightData.velocity = signal(globalPosition, origin, 'GLOBAL_POSITION_INT', ...
            {'vx', 'vy', 'vz'}, columns(globalPosition, {'vx', 'vy', 'vz'}) / 100, componentID);
    elseif ~isempty(gps)
        flightData = geographicPosition(flightData, gps, origin, ...
            'GPS_RAW_INT', componentID, true);
    else
        error('FLIP:MissingTLogPose', ...
            'LOCAL_POSITION_NED, GLOBAL_POSITION_INT, or GPS_RAW_INT is required.');
    end
    if nnz(all(isfinite(columnsFromSignal(flightData.position, {'x', 'y', 'z'})), 2)) < 2
        error('FLIP:InsufficientTLogPosition', ...
            'At least two valid position samples are required. Check GPS fix availability.');
    end

    target = payload(messages, 'POSITION_TARGET_LOCAL_NED');
    if ~isempty(target) && ~isempty(local)
        % MAV_FRAME_LOCAL_NED (1) uses the logged local-state origin.
        values = columns(target, {'x', 'y', 'z', 'vx', 'vy', 'vz', 'yaw', 'yaw_rate'});
        mask = columns(target, {'type_mask'});
        bits = [1 2 3 4 5 6 11 12];
        for index = 1:numel(bits)
            values(bitget(uint16(mask), bits(index)) ~= 0, index) = NaN;
        end
        values(columns(target, {'coordinate_frame'}) ~= 1, :) = NaN;
        flightData.positionSetpoint = signal(target, origin, 'POSITION_TARGET_LOCAL_NED', ...
            {'x', 'y', 'z', 'yaw'}, values(:, [1 2 3 7]), componentID);
        flightData.velocitySetpoint = signal(target, origin, 'POSITION_TARGET_LOCAL_NED', ...
            {'vx', 'vy', 'vz', 'yawSpeed'}, values(:, [4 5 6 8]), componentID);
    end
    target = payload(messages, 'ATTITUDE_TARGET');
    if ~isempty(target)
        q = double(target.q);
        if size(q, 2) ~= 4
            error('FLIP:InvalidTLogQuaternion', 'ATTITUDE_TARGET.q must be N-by-4.');
        end
        mask = uint8(columns(target, {'type_mask'}));
        q(bitget(mask, 8) ~= 0, :) = NaN;
        flightData.attitudeSetpoint = signal(target, origin, 'ATTITUDE_TARGET', ...
            {'q0', 'q1', 'q2', 'q3'}, q, componentID);
        rates = columns(target, {'body_roll_rate', 'body_pitch_rate', 'body_yaw_rate'});
        for index = 1:3
            rates(bitget(mask, index) ~= 0, index) = NaN;
        end
        flightData.ratesSetpoint = signal(target, origin, 'ATTITUDE_TARGET', ...
            {'roll', 'pitch', 'yaw'}, rates, componentID);
    end

    flightData.catalog = messageCatalog(messages, origin);
    flightData.metadata.topicCount = height(flightData.catalog);
    flightData.metadata.supportedTopicCount = nnz(flightData.catalog.Supported);
end

function validateID(value)
    if ~isnan(value) && ~(isfinite(value) && value >= 0 && value <= 255 && value == fix(value))
        error('FLIP:InvalidMAVLinkID', 'MAVLink IDs must be integers from 0 to 255, or NaN for automatic selection.');
    end
end

function [systemID, componentID] = selectVehicle(messages, options)
    names = string(messages.MessageName);
    attitude = ismember(names, ["ATTITUDE", "ATTITUDE_QUATERNION"]);
    pairs = unique([double(messages.SystemID(attitude)), double(messages.ComponentID(attitude))], 'rows');
    keep = false(size(pairs, 1), 1);
    for index = 1:size(pairs, 1)
        same = double(messages.SystemID) == pairs(index, 1) & double(messages.ComponentID) == pairs(index, 2);
        keep(index) = any(same & ismember(names, ...
            ["LOCAL_POSITION_NED", "GLOBAL_POSITION_INT", "GPS_RAW_INT"])) && ...
            (isnan(options.SystemID) || pairs(index, 1) == options.SystemID) && ...
            (isnan(options.ComponentID) || pairs(index, 2) == options.ComponentID);
    end
    pairs = pairs(keep, :);
    if isempty(pairs)
        error('FLIP:MissingTLogPose', 'No single MAVLink system/component has both supported attitude and position data.');
    end
    if size(pairs, 1) > 1
        error('FLIP:AmbiguousTLogVehicle', ...
            'Multiple vehicles contain pose data. Use loadTLog(file, SystemID=..., ComponentID=...) to select one.');
    end
    systemID = pairs(1, 1);
    componentID = pairs(1, 2);
end

function data = payload(messages, name)
    rows = find(string(messages.MessageName) == string(name));
    data = timetable();
    for row = reshape(rows, 1, [])
        current = messages.Messages{row};
        % Common payload fields support concatenation across MAVLink versions.
        switch name
            case 'ATTITUDE'
                fields = {'roll','pitch','yaw','rollspeed','pitchspeed','yawspeed'};
            case 'ATTITUDE_QUATERNION'
                fields = {'q1','q2','q3','q4','rollspeed','pitchspeed','yawspeed'};
            case 'LOCAL_POSITION_NED'
                fields = {'x','y','z','vx','vy','vz'};
            case 'GLOBAL_POSITION_INT'
                fields = {'lat','lon','alt','vx','vy','vz'};
            case 'GPS_RAW_INT'
                fields = {'lat','lon','alt','fix_type'};
            case 'POSITION_TARGET_LOCAL_NED'
                fields = {'x','y','z','vx','vy','vz','yaw','yaw_rate','type_mask','coordinate_frame'};
            case 'ATTITUDE_TARGET'
                fields = {'q','body_roll_rate','body_pitch_rate','body_yaw_rate','type_mask'};
        end
        if ~all(ismember(fields, current.Properties.VariableNames))
            error('FLIP:MissingTLogField', 'Missing required fields in %s.', name);
        end
        current = current(:, fields);
        if isempty(data)
            data = current;
        else
            data = [data; current]; %#ok<AGROW>
        end
    end
    if ~isempty(data)
        data = sortrows(data);
        [~, indices] = unique(data.Properties.RowTimes, 'last');
        data = data(sort(indices), :);
    end
end

function values = columns(data, names)
    if ~all(ismember(names, data.Properties.VariableNames))
        error('FLIP:MissingTLogField', 'Missing MAVLink payload field(s): %s', strjoin(names, ', '));
    end
    values = double(data{:, names});
end

function result = emptySignal(fields)
    result = struct('available', false, 'topicName', '', 'instanceID', NaN, 'time', zeros(0, 1));
    for index = 1:numel(fields)
        result.(fields{index}) = zeros(0, 1);
    end
end

function result = signal(data, origin, name, fields, values, componentID)
    result = emptySignal(fields);
    result.available = any(isfinite(values), 'all');
    result.topicName = name;
    result.instanceID = componentID;
    result.time = seconds(data.Properties.RowTimes - origin);
    result.recordedTime = data.Properties.RowTimes;
    for index = 1:numel(fields)
        result.(fields{index}) = values(:, index);
    end
end

function values = columnsFromSignal(data, names)
    values = zeros(numel(data.time), numel(names));
    for index = 1:numel(names)
        values(:, index) = data.(names{index});
    end
end

function q = eulerQuaternion(rpy)
    c = cos(rpy / 2);
    s = sin(rpy / 2);
    q = [c(:, 1).*c(:, 2).*c(:, 3) + s(:, 1).*s(:, 2).*s(:, 3), ...
        s(:, 1).*c(:, 2).*c(:, 3) - c(:, 1).*s(:, 2).*s(:, 3), ...
        c(:, 1).*s(:, 2).*c(:, 3) + s(:, 1).*c(:, 2).*s(:, 3), ...
        c(:, 1).*c(:, 2).*s(:, 3) - s(:, 1).*s(:, 2).*c(:, 3)];
end

function flightData = geographicPosition(flightData, data, origin, name, componentID, requireFix)
    lla = columns(data, {'lat', 'lon', 'alt'}) ./ [1e7 1e7 1e3];
    valid = validGeographicRows(data, requireFix);
    first = find(valid, 1, 'first');
    if isempty(first)
        error('FLIP:InsufficientTLogPosition', 'No valid geographic positions with 3D GPS fix are available.');
    end
    lla(~valid, :) = NaN;
    lat = deg2rad(lla(:, 1));
    lon = deg2rad(lla(:, 2));
    a = 6378137;
    eccentricitySquared = (1 / 298.257223563) * (2 - 1 / 298.257223563);
    radius = a ./ sqrt(1 - eccentricitySquared .* sin(lat).^2);
    surface = [radius.*cos(lat).*cos(lon), radius.*cos(lat).*sin(lon), ...
        radius.*(1 - eccentricitySquared).*sin(lat)];
    delta = surface - surface(first, :);
    lat0 = lat(first);
    lon0 = lon(first);
    north = delta * [-sin(lat0)*cos(lon0); -sin(lat0)*sin(lon0); cos(lat0)];
    east = delta * [-sin(lon0); cos(lon0); 0];
    down = lla(first, 3) - lla(:, 3);
    flightData.position = signal(data, origin, name, {'x', 'y', 'z'}, ...
        [north east down], componentID);
    flightData.geographicPosition = signal(data, origin, name, ...
        {'latitude', 'longitude', 'altitudeMSL'}, lla, componentID);
    flightData.metadata.geographicOrigin = lla(first, :);
    flightData.metadata.positionConversion = [ ...
        'Approximate local NED: WGS84 surface ECEF projected onto first-fix North/East; ' ...
        'Down = first MSL altitude - MSL altitude. Not the autopilot local origin.'];
end

function valid = validGeographicRows(data, requireFix)
    lla = columns(data, {'lat', 'lon', 'alt'}) ./ [1e7 1e7 1e3];
    valid = all(isfinite(lla), 2) & abs(lla(:, 1)) <= 90 & ...
        abs(lla(:, 2)) <= 180 & ~(lla(:, 1) == 0 & lla(:, 2) == 0);
    if requireFix
        valid = valid & columns(data, {'fix_type'}) >= 3;
    end
end

function catalog = messageCatalog(messages, origin)
    count = height(messages);
    startTime = NaN(count, 1);
    endTime = NaN(count, 1);
    sampleCount = zeros(count, 1);
    for index = 1:count
        data = messages.Messages{index};
        sampleCount(index) = height(data);
        if ~isempty(data)
            time = seconds(data.Properties.RowTimes - origin);
            startTime(index) = min(time);
            endTime(index) = max(time);
        end
    end
    catalog = table(string(messages.MessageName), double(messages.ComponentID), ...
        startTime, endTime, sampleCount, true(count, 1), ...
        repmat("flight_state_or_reference", count, 1), double(messages.SystemID), ...
        'VariableNames', {'TopicName', 'InstanceID', 'StartTime', 'EndTime', ...
        'SampleCount', 'Supported', 'Category', 'SystemID'});
end
