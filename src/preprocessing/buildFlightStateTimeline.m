function flightData = buildFlightStateTimeline(flightData)
% Build a common timeline of flight mode, arming, landing, safety, and reference states.

    timeline = emptyTimeline();

    timeline = appendLogicalState(timeline, flightData, ...
        'armingState', 'armed', 'Arming', ...
        "Armed", "Disarmed", false, 'actuator_armed');
    timeline = appendNavigationState(timeline, flightData);
    timeline = appendLogicalState(timeline, flightData, ...
        'landDetection', 'landed', 'Landing', ...
        "Landed", "Airborne", false, 'vehicle_land_detected');
    timeline = appendLogicalState(timeline, flightData, ...
        'landDetection', 'groundContact', 'Ground contact', ...
        "Contact", "No contact", false, 'vehicle_land_detected');
    timeline = appendLogicalState(timeline, flightData, ...
        'landDetection', 'freefall', 'Freefall', ...
        "Detected", "Not detected", true, 'vehicle_land_detected');
    timeline = appendLogicalState(timeline, flightData, ...
        'vehicleStatus', 'failsafe', 'Failsafe', ...
        "Active", "Clear", true, 'vehicle_status');
    timeline = appendLogicalState(timeline, flightData, ...
        'failureDetector', 'active', 'Failure detector', ...
        "Active", "Clear", true, 'failure_detector_status');

    timeline = appendSetpointValidity(timeline, flightData, ...
        'positionSetpoint', {'x', 'y', 'z'}, ...
        'Position setpoint', 'vehicle_local_position_setpoint');
    timeline = appendSetpointValidity(timeline, flightData, ...
        'attitudeSetpoint', {'q0', 'q1', 'q2', 'q3'}, ...
        'Attitude setpoint', 'vehicle_attitude_setpoint');
    timeline = appendSetpointValidity(timeline, flightData, ...
        'ratesSetpoint', {'roll', 'pitch', 'yaw'}, ...
        'Rate setpoint', 'vehicle_rates_setpoint');

    if ~isempty(timeline)

        timeline = sortrows(timeline, {'Time', 'Category'});

    end

    flightData.stateTimeline = timeline;

end


function timeline = appendNavigationState(timeline, flightData)

    if ~hasTimedField(flightData, 'vehicleStatus', 'navState')

        return;

    end

    signal = flightData.vehicleStatus;
    time = signal.time(:);
    value = double(signal.navState(:));
    valid = isfinite(time) & isfinite(value);
    time = time(valid);
    value = value(valid);
    change = changeMask(value);
    time = time(change);
    value = value(change);
    state = strings(numel(value), 1);

    for index = 1:numel(value)

        state(index) = navigationStateLabel(value(index));

    end

    timeline = appendRows(timeline, time, ...
        repmat("Flight mode", numel(time), 1), state, value, ...
        repmat("vehicle_status", numel(time), 1), ...
        false(numel(time), 1));

end


function timeline = appendLogicalState(timeline, flightData, ...
        signalName, fieldName, category, trueLabel, falseLabel, ...
        trueIsAlert, source)

    if ~hasTimedField(flightData, signalName, fieldName)

        return;

    end

    signal = flightData.(signalName);
    time = signal.time(:);
    rawValue = double(signal.(fieldName)(:));
    valid = isfinite(time) & isfinite(rawValue);
    time = time(valid);
    value = logical(rawValue(valid));
    change = changeMask(value);
    time = time(change);
    value = value(change);
    state = repmat(falseLabel, numel(value), 1);
    state(value) = trueLabel;
    isAlert = false(numel(value), 1);

    if trueIsAlert

        isAlert = value;

    end

    timeline = appendRows(timeline, time, ...
        repmat(string(category), numel(time), 1), state, double(value), ...
        repmat(string(source), numel(time), 1), isAlert);

end


function timeline = appendSetpointValidity(timeline, flightData, ...
        signalName, fieldNames, category, source)

    if ~isfield(flightData, signalName)

        return;

    end

    signal = flightData.(signalName);

    if ~isfield(signal, 'time') || isempty(signal.time) || ...
            ~all(isfield(signal, fieldNames))

        return;

    end

    if isfield(signal, 'topicName') && ~isempty(signal.topicName)
        source = signal.topicName;
    end

    time = signal.time(:);
    values = zeros(numel(time), numel(fieldNames));

    for fieldIndex = 1:numel(fieldNames)

        values(:, fieldIndex) = signal.(fieldNames{fieldIndex})(:);

    end

    validTime = isfinite(time);
    time = time(validTime);
    values = values(validTime, :);

    if strcmp(signalName, 'attitudeSetpoint')

        validSetpoint = all(isfinite(values), 2) & ...
            sqrt(sum(values .^ 2, 2)) > 0;

    else

        validSetpoint = any(isfinite(values), 2);

    end

    change = changeMask(validSetpoint);
    time = time(change);
    validSetpoint = validSetpoint(change);
    state = repmat("Invalid", numel(time), 1);
    state(validSetpoint) = "Valid";

    timeline = appendRows(timeline, time, ...
        repmat(string(category), numel(time), 1), state, ...
        double(validSetpoint), repmat(string(source), numel(time), 1), ...
        false(numel(time), 1));

end


function result = hasTimedField(flightData, signalName, fieldName)

    result = isfield(flightData, signalName) && ...
        isfield(flightData.(signalName), 'time') && ...
        isfield(flightData.(signalName), fieldName) && ...
        ~isempty(flightData.(signalName).time) && ...
        numel(flightData.(signalName).time) == ...
        numel(flightData.(signalName).(fieldName));

end


function change = changeMask(value)

    change = true(size(value));

    if numel(value) > 1

        change(2:end) = value(2:end) ~= value(1:end-1);

    end

end


function timeline = appendRows(timeline, time, category, state, value, ...
        source, isAlert)

    rows = table(time(:), category(:), state(:), value(:), source(:), ...
        isAlert(:), false(numel(time), 1), 'VariableNames', ...
        {'Time', 'Category', 'State', 'Value', 'Source', 'IsAlert', ...
        'IsInherited'});
    timeline = [timeline; rows];

end


function timeline = emptyTimeline()

    timeline = table( ...
        zeros(0, 1), strings(0, 1), strings(0, 1), zeros(0, 1), ...
        strings(0, 1), false(0, 1), false(0, 1), ...
        'VariableNames', ...
        {'Time', 'Category', 'State', 'Value', 'Source', 'IsAlert', ...
        'IsInherited'});

end


function label = navigationStateLabel(value)

    labels = [ ...
        "Manual", "Altitude control", "Position control", ...
        "Auto mission", "Auto loiter", "Auto RTL", ...
        "Position slow", "Reserved 7", "Reserved 8", ...
        "Reserved 9", "Acro", "Reserved 11", "Descend", ...
        "Termination", "Offboard", "Stabilized", "Reserved 16", ...
        "Auto takeoff", "Auto land", "Auto follow target", ...
        "Auto precision land", "Orbit", "Auto VTOL takeoff", ...
        "External 1", "External 2", "External 3", ...
        "External 4", "External 5", "External 6", ...
        "External 7", "External 8"];
    index = round(value) + 1;

    if value == round(value) && index >= 1 && index <= numel(labels)

        label = labels(index);

    else

        label = sprintf('Unknown (%g)', value);

    end

end
