function flightData = addEulerAngles(flightData)
% Compute roll, pitch, and yaw from actual and reference quaternions.

    flightData.attitude = convertSignal(flightData.attitude);

    if isfield(flightData, 'attitudeSetpoint')

        flightData.attitudeSetpoint = ...
            convertSignal(flightData.attitudeSetpoint);

    end

    flightData.metadata.attitudeUnit = 'radians';
    flightData.metadata.quaternionConvention = 'Hamilton [w x y z]';
    flightData.metadata.attitudeRotation = ...
        'FRD body frame to NED earth frame';
    flightData.metadata.eulerConvention = 'ZYX yaw-pitch-roll';

end


function signal = convertSignal(signal)

    signal.roll = zeros(0, 1);
    signal.pitch = zeros(0, 1);
    signal.yaw = zeros(0, 1);

    if isfield(signal, 'available') && ~signal.available

        return;

    end

    requiredFields = {'q0', 'q1', 'q2', 'q3'};

    if ~all(isfield(signal, requiredFields))

        error('FLIP:MissingQuaternionFields', ...
            'Attitude signal does not contain q0, q1, q2, and q3.');

    end

    quaternion = [signal.q0, signal.q1, signal.q2, signal.q3];
    [signal.roll, signal.pitch, signal.yaw] = ...
        quaternionToEuler(quaternion);

end
