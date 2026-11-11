function flightData = loadULog(logFile)
% Read PX4 topics, parameters, and signal data into the FLIP structure.

    %% Validate input and environment

    if nargin < 1

        error('FLIP:MissingLogFile', ...
            'A PX4 ULog file path must be provided.');

    end

    logFile = validateLogFile(logFile);
    validateULogEnvironment();


    %% Read ULog

    try

        ulog = ulogreader(logFile);

    catch exception

        error('FLIP:ULogReadFailed', ...
            'Could not read the PX4 ULog file:\n%s\n\nReason: %s', ...
            logFile, exception.message);

    end


    %% Build ULog catalog

    catalog = buildULogCatalog(ulog);


    %% Read required actual-state topics

    attitudeInstance = selectTopicInstance( ...
        ulog.AvailableTopics, 'vehicle_attitude');

    positionInstance = selectTopicInstance( ...
        ulog.AvailableTopics, 'vehicle_local_position');


    attitudeMessages = readRequiredTopic( ...
        ulog, 'vehicle_attitude', attitudeInstance);

    positionMessages = readRequiredTopic( ...
        ulog, 'vehicle_local_position', positionInstance);


    %% Read optional actual-state and setpoint topics

    [ratesMessages, ratesInstance] = readOptionalTopic( ...
        ulog, 'vehicle_angular_velocity');

    [localSetpointMessages, localSetpointInstance] = ...
        readOptionalTopic(ulog, 'vehicle_local_position_setpoint');

    [trajectorySetpointMessages, trajectorySetpointInstance] = ...
        readOptionalTopic(ulog, 'trajectory_setpoint');

    [attitudeSetpointMessages, attitudeSetpointInstance] = ...
        readOptionalTopic(ulog, 'vehicle_attitude_setpoint');

    [ratesSetpointMessages, ratesSetpointInstance] = ...
        readOptionalTopic(ulog, 'vehicle_rates_setpoint');

    [vehicleStatusMessages, vehicleStatusInstance] = ...
        readOptionalTopic(ulog, 'vehicle_status');

    [armingMessages, armingInstance] = ...
        readOptionalTopic(ulog, 'actuator_armed');

    [landDetectionMessages, landDetectionInstance] = ...
        readOptionalTopic(ulog, 'vehicle_land_detected');

    [failureDetectorMessages, failureDetectorInstance] = ...
        readOptionalTopic(ulog, 'failure_detector_status');

    [motorCommandMessages, motorCommandInstance] = ...
        readOptionalTopic(ulog, 'actuator_motors');

    [actuatorOutputMessages, actuatorOutputInstance] = ...
        readOptionalTopic(ulog, 'actuator_outputs');

    [batteryMessages, batteryInstance] = ...
        readOptionalTopic(ulog, 'battery_status');

    [estimatorSelectorMessages, estimatorSelectorInstance] = ...
        readOptionalTopic(ulog, 'estimator_selector_status');
    preferredEstimatorInstance = lastFiniteScalarField( ...
        estimatorSelectorMessages, 'primary_instance', NaN);

    [estimatorStatusMessages, estimatorStatusInstance] = ...
        readOptionalTopic(ulog, 'estimator_status', ...
        preferredEstimatorInstance);
    [estimatorInnovationMessages, estimatorInnovationInstance] = ...
        readOptionalTopic(ulog, 'estimator_innovations', ...
        estimatorStatusInstance);
    [estimatorRatioMessages, estimatorRatioInstance] = ...
        readOptionalTopic(ulog, 'estimator_innovation_test_ratios', ...
        estimatorStatusInstance);

    selectedAccelDevice = lastFiniteScalarField( ...
        estimatorStatusMessages, 'accel_device_id', NaN);
    [imuStatusMessages, imuStatusInstance] = ...
        readOptionalTopicMatchingField(ulog, 'vehicle_imu_status', ...
        'accel_device_id', selectedAccelDevice);
    [imuConsistencyMessages, imuConsistencyInstance] = ...
        readOptionalTopic(ulog, 'sensors_status_imu');

    [gpsMessages, gpsInstance] = ...
        readOptionalTopic(ulog, 'vehicle_gps_position');
    [thrustMessages, thrustInstance] = ...
        readOptionalTopic(ulog, 'vehicle_thrust_setpoint');
    [torqueMessages, torqueInstance] = ...
        readOptionalTopic(ulog, 'vehicle_torque_setpoint');
    [manualControlMessages, manualControlInstance] = ...
        readOptionalTopic(ulog, 'manual_control_setpoint');
    [inputRCMessages, inputRCInstance] = ...
        readOptionalTopic(ulog, 'input_rc');
    [cpuMessages, cpuInstance] = readOptionalTopic(ulog, 'cpuload');
    [radioMessages, radioInstance] = ...
        readOptionalTopic(ulog, 'radio_status');
    [telemetryMessages, telemetryInstance] = ...
        readOptionalTopic(ulog, 'telemetry_status');
    [systemPowerMessages, systemPowerInstance] = ...
        readOptionalTopic(ulog, 'system_power');

    parameterTable = readOptionalParameters(ulog);


    %% Validate extracted fields

    validateTopicFields(attitudeMessages, {'q'}, 'vehicle_attitude');
    validateTopicFields(positionMessages, ...
        {'x', 'y', 'z', 'vx', 'vy', 'vz'}, ...
        'vehicle_local_position');

    validateVectorWidth(attitudeMessages, 'q', 4, ...
        'vehicle_attitude');

    if ~isempty(ratesMessages)
        validateTopicFields(ratesMessages, {'xyz'}, ...
            'vehicle_angular_velocity');
        validateVectorWidth(ratesMessages, 'xyz', 3, ...
            'vehicle_angular_velocity');
    end

    if ~isempty(localSetpointMessages)
        validateTopicFields(localSetpointMessages, ...
            {'x', 'y', 'z', 'vx', 'vy', 'vz', 'yaw', 'yawspeed'}, ...
            'vehicle_local_position_setpoint');
    end

    if ~isempty(trajectorySetpointMessages)
        validateTopicFields(trajectorySetpointMessages, ...
            {'position', 'velocity', 'acceleration', 'yaw', 'yawspeed'}, ...
            'trajectory_setpoint');
        validateVectorWidth(trajectorySetpointMessages, 'position', 3, ...
            'trajectory_setpoint');
        validateVectorWidth(trajectorySetpointMessages, 'velocity', 3, ...
            'trajectory_setpoint');
        validateVectorWidth(trajectorySetpointMessages, 'acceleration', 3, ...
            'trajectory_setpoint');
    end

    if ~isempty(attitudeSetpointMessages)
        validateTopicFields(attitudeSetpointMessages, {'q_d'}, ...
            'vehicle_attitude_setpoint');
        validateVectorWidth(attitudeSetpointMessages, 'q_d', 4, ...
            'vehicle_attitude_setpoint');
    end

    if ~isempty(ratesSetpointMessages)
        validateTopicFields(ratesSetpointMessages, ...
            {'roll', 'pitch', 'yaw'}, 'vehicle_rates_setpoint');
    end

    if ~isempty(motorCommandMessages)
        validateTopicFields(motorCommandMessages, {'control'}, ...
            'actuator_motors');
    end

    if ~isempty(actuatorOutputMessages)
        validateTopicFields(actuatorOutputMessages, ...
            {'noutputs', 'output'}, 'actuator_outputs');
    end


    %% Create MATLAB-native flight data

    [~, fileName, extension] = fileparts(logFile);

    flightData = struct();
    flightData.fileName = [fileName, extension];

    flightData.metadata = struct();
    flightData.metadata.sourceFile = logFile;
    flightData.metadata.backend = 'MATLAB UAV Toolbox';
    flightData.metadata.timeUnit = 'seconds';
    flightData.metadata.logStartTime = seconds(ulog.StartTime);
    flightData.metadata.logEndTime = seconds(ulog.EndTime);
    flightData.metadata.dropoutIntervals = ...
        seconds(ulog.DropoutIntervals);
    flightData.metadata.topicCount = height(catalog);
    flightData.metadata.supportedTopicCount = sum(catalog.Supported);

    flightData.catalog = catalog;

    flightData.attitude = struct();
    flightData.attitude.available = true;
    flightData.attitude.topicName = 'vehicle_attitude';
    flightData.attitude.instanceID = attitudeInstance;
    flightData.attitude.time = ...
        seconds(attitudeMessages.Properties.RowTimes(:));
    flightData.attitude.q0 = double(attitudeMessages.q(:, 1));
    flightData.attitude.q1 = double(attitudeMessages.q(:, 2));
    flightData.attitude.q2 = double(attitudeMessages.q(:, 3));
    flightData.attitude.q3 = double(attitudeMessages.q(:, 4));

    flightData.position = struct();
    flightData.position.available = true;
    flightData.position.topicName = 'vehicle_local_position';
    flightData.position.instanceID = positionInstance;
    flightData.position.time = ...
        seconds(positionMessages.Properties.RowTimes(:));
    flightData.position.x = double(positionMessages.x(:));
    flightData.position.y = double(positionMessages.y(:));
    flightData.position.z = double(positionMessages.z(:));

    flightData.velocity = struct();
    flightData.velocity.available = true;
    flightData.velocity.topicName = 'vehicle_local_position';
    flightData.velocity.instanceID = positionInstance;
    flightData.velocity.time = flightData.position.time;
    flightData.velocity.vx = double(positionMessages.vx(:));
    flightData.velocity.vy = double(positionMessages.vy(:));
    flightData.velocity.vz = double(positionMessages.vz(:));

    flightData.rates = createSignalHeader( ...
        'vehicle_angular_velocity', ratesInstance, ratesMessages);
    flightData.rates.roll = zeros(0, 1);
    flightData.rates.pitch = zeros(0, 1);
    flightData.rates.yaw = zeros(0, 1);

    if flightData.rates.available
        flightData.rates.roll = double(ratesMessages.xyz(:, 1));
        flightData.rates.pitch = double(ratesMessages.xyz(:, 2));
        flightData.rates.yaw = double(ratesMessages.xyz(:, 3));
    end

    flightData.positionSetpoint = createSignalHeader( ...
        'vehicle_local_position_setpoint', localSetpointInstance, ...
        localSetpointMessages);
    flightData.positionSetpoint.x = zeros(0, 1);
    flightData.positionSetpoint.y = zeros(0, 1);
    flightData.positionSetpoint.z = zeros(0, 1);
    flightData.positionSetpoint.yaw = zeros(0, 1);

    flightData.velocitySetpoint = createSignalHeader( ...
        'vehicle_local_position_setpoint', localSetpointInstance, ...
        localSetpointMessages);
    flightData.velocitySetpoint.vx = zeros(0, 1);
    flightData.velocitySetpoint.vy = zeros(0, 1);
    flightData.velocitySetpoint.vz = zeros(0, 1);
    flightData.velocitySetpoint.yawSpeed = zeros(0, 1);

    if flightData.positionSetpoint.available
        flightData.positionSetpoint.x = double(localSetpointMessages.x(:));
        flightData.positionSetpoint.y = double(localSetpointMessages.y(:));
        flightData.positionSetpoint.z = double(localSetpointMessages.z(:));
        flightData.positionSetpoint.yaw = ...
            double(localSetpointMessages.yaw(:));

        flightData.velocitySetpoint.vx = double(localSetpointMessages.vx(:));
        flightData.velocitySetpoint.vy = double(localSetpointMessages.vy(:));
        flightData.velocitySetpoint.vz = double(localSetpointMessages.vz(:));
        flightData.velocitySetpoint.yawSpeed = ...
            double(localSetpointMessages.yawspeed(:));
    end

    flightData.trajectorySetpoint = createSignalHeader( ...
        'trajectory_setpoint', trajectorySetpointInstance, ...
        trajectorySetpointMessages);
    flightData.trajectorySetpoint.x = zeros(0, 1);
    flightData.trajectorySetpoint.y = zeros(0, 1);
    flightData.trajectorySetpoint.z = zeros(0, 1);
    flightData.trajectorySetpoint.vx = zeros(0, 1);
    flightData.trajectorySetpoint.vy = zeros(0, 1);
    flightData.trajectorySetpoint.vz = zeros(0, 1);
    flightData.trajectorySetpoint.ax = zeros(0, 1);
    flightData.trajectorySetpoint.ay = zeros(0, 1);
    flightData.trajectorySetpoint.az = zeros(0, 1);
    flightData.trajectorySetpoint.yaw = zeros(0, 1);
    flightData.trajectorySetpoint.yawSpeed = zeros(0, 1);

    if flightData.trajectorySetpoint.available
        flightData.trajectorySetpoint.x = ...
            double(trajectorySetpointMessages.position(:, 1));
        flightData.trajectorySetpoint.y = ...
            double(trajectorySetpointMessages.position(:, 2));
        flightData.trajectorySetpoint.z = ...
            double(trajectorySetpointMessages.position(:, 3));
        flightData.trajectorySetpoint.vx = ...
            double(trajectorySetpointMessages.velocity(:, 1));
        flightData.trajectorySetpoint.vy = ...
            double(trajectorySetpointMessages.velocity(:, 2));
        flightData.trajectorySetpoint.vz = ...
            double(trajectorySetpointMessages.velocity(:, 3));
        flightData.trajectorySetpoint.ax = ...
            double(trajectorySetpointMessages.acceleration(:, 1));
        flightData.trajectorySetpoint.ay = ...
            double(trajectorySetpointMessages.acceleration(:, 2));
        flightData.trajectorySetpoint.az = ...
            double(trajectorySetpointMessages.acceleration(:, 3));
        flightData.trajectorySetpoint.yaw = ...
            double(trajectorySetpointMessages.yaw(:));
        flightData.trajectorySetpoint.yawSpeed = ...
            double(trajectorySetpointMessages.yawspeed(:));
    end

    flightData.attitudeSetpoint = createSignalHeader( ...
        'vehicle_attitude_setpoint', attitudeSetpointInstance, ...
        attitudeSetpointMessages);
    flightData.attitudeSetpoint.q0 = zeros(0, 1);
    flightData.attitudeSetpoint.q1 = zeros(0, 1);
    flightData.attitudeSetpoint.q2 = zeros(0, 1);
    flightData.attitudeSetpoint.q3 = zeros(0, 1);

    if flightData.attitudeSetpoint.available
        flightData.attitudeSetpoint.q0 = ...
            double(attitudeSetpointMessages.q_d(:, 1));
        flightData.attitudeSetpoint.q1 = ...
            double(attitudeSetpointMessages.q_d(:, 2));
        flightData.attitudeSetpoint.q2 = ...
            double(attitudeSetpointMessages.q_d(:, 3));
        flightData.attitudeSetpoint.q3 = ...
            double(attitudeSetpointMessages.q_d(:, 4));
    end

    flightData.ratesSetpoint = createSignalHeader( ...
        'vehicle_rates_setpoint', ratesSetpointInstance, ...
        ratesSetpointMessages);
    flightData.ratesSetpoint.roll = zeros(0, 1);
    flightData.ratesSetpoint.pitch = zeros(0, 1);
    flightData.ratesSetpoint.yaw = zeros(0, 1);

    if flightData.ratesSetpoint.available
        flightData.ratesSetpoint.roll = ...
            double(ratesSetpointMessages.roll(:));
        flightData.ratesSetpoint.pitch = ...
            double(ratesSetpointMessages.pitch(:));
        flightData.ratesSetpoint.yaw = ...
            double(ratesSetpointMessages.yaw(:));
    end

    flightData.vehicleStatus = createSignalHeader( ...
        'vehicle_status', vehicleStatusInstance, vehicleStatusMessages);
    flightData.vehicleStatus.navState = extractOptionalField( ...
        vehicleStatusMessages, 'nav_state');
    flightData.vehicleStatus.failsafe = extractOptionalField( ...
        vehicleStatusMessages, 'failsafe');

    flightData.armingState = createSignalHeader( ...
        'actuator_armed', armingInstance, armingMessages);
    flightData.armingState.armed = extractOptionalField( ...
        armingMessages, 'armed');

    flightData.landDetection = createSignalHeader( ...
        'vehicle_land_detected', landDetectionInstance, ...
        landDetectionMessages);
    flightData.landDetection.landed = extractOptionalField( ...
        landDetectionMessages, 'landed');
    flightData.landDetection.groundContact = extractOptionalField( ...
        landDetectionMessages, 'ground_contact');
    flightData.landDetection.freefall = extractOptionalField( ...
        landDetectionMessages, 'freefall');

    flightData.failureDetector = createSignalHeader( ...
        'failure_detector_status', failureDetectorInstance, ...
        failureDetectorMessages);
    flightData.failureDetector.active = ...
        aggregateFailureDetector(failureDetectorMessages);

    flightData.motorCommand = createSignalHeader( ...
        'actuator_motors', motorCommandInstance, motorCommandMessages);
    flightData.motorCommand.control = zeros(0, 0);
    flightData.motorCommand.reversibleFlags = zeros(0, 1);
    flightData.motorCommand.validChannelMask = false(1, 0);
    flightData.motorCommand.channelCount = 0;
    flightData.motorCommand.unit = 'normalized command';

    if flightData.motorCommand.available
        flightData.motorCommand.control = ...
            double(motorCommandMessages.control);
        flightData.motorCommand.reversibleFlags = ...
            extractOptionalField(motorCommandMessages, ...
            'reversible_flags');
        flightData.motorCommand.validChannelMask = ...
            any(isfinite(flightData.motorCommand.control), 1);
        flightData.motorCommand.channelCount = ...
            nnz(flightData.motorCommand.validChannelMask);
    end

    flightData.actuatorOutput = createSignalHeader( ...
        'actuator_outputs', actuatorOutputInstance, ...
        actuatorOutputMessages);
    flightData.actuatorOutput.output = zeros(0, 0);
    flightData.actuatorOutput.nOutputs = zeros(0, 1);
    flightData.actuatorOutput.validChannelMask = false(1, 0);
    flightData.actuatorOutput.channelCount = 0;
    flightData.actuatorOutput.outputFunction = zeros(1, 0);
    flightData.actuatorOutput.motorNumber = zeros(1, 0);
    flightData.actuatorOutput.minimum = zeros(1, 0);
    flightData.actuatorOutput.maximum = zeros(1, 0);
    flightData.actuatorOutput.disarmed = zeros(1, 0);
    flightData.actuatorOutput.mappingAvailable = false;
    flightData.actuatorOutput.mappingSource = '';
    flightData.actuatorOutput.unit = 'raw actuator output';

    if flightData.actuatorOutput.available
        output = double(actuatorOutputMessages.output);
        nOutputs = double(actuatorOutputMessages.noutputs(:));
        output = maskUnusedActuatorOutputs(output, nOutputs);
        mapping = buildActuatorOutputMapping( ...
            parameterTable, actuatorOutputInstance, size(output, 2));

        flightData.actuatorOutput.output = output;
        flightData.actuatorOutput.nOutputs = nOutputs;
        flightData.actuatorOutput.validChannelMask = ...
            any(isfinite(output), 1);
        flightData.actuatorOutput.channelCount = ...
            nnz(flightData.actuatorOutput.validChannelMask);
        flightData.actuatorOutput.outputFunction = ...
            mapping.outputFunction;
        flightData.actuatorOutput.motorNumber = mapping.motorNumber;
        flightData.actuatorOutput.minimum = mapping.minimum;
        flightData.actuatorOutput.maximum = mapping.maximum;
        flightData.actuatorOutput.disarmed = mapping.disarmed;
        flightData.actuatorOutput.mappingAvailable = ...
            mapping.available;
        flightData.actuatorOutput.mappingSource = mapping.source;

        if mapping.available
            flightData.actuatorOutput.unit = 'PWM microseconds';
        end
    end

    flightData.battery = createSignalHeader( ...
        'battery_status', batteryInstance, batteryMessages);
    flightData.battery.voltage = extractOptionalField( ...
        batteryMessages, 'voltage_v');
    flightData.battery.current = extractOptionalField( ...
        batteryMessages, 'current_a');
    flightData.battery.currentAverage = extractOptionalField( ...
        batteryMessages, 'current_average_a');
    flightData.battery.dischargedMah = extractOptionalField( ...
        batteryMessages, 'discharged_mah');
    flightData.battery.remaining = extractOptionalField( ...
        batteryMessages, 'remaining');
    flightData.battery.timeRemaining = extractOptionalField( ...
        batteryMessages, 'time_remaining_s');
    flightData.battery.temperature = extractOptionalField( ...
        batteryMessages, 'temperature');
    flightData.battery.cellVoltage = extractOptionalMatrixField( ...
        batteryMessages, 'voltage_cell_v');
    flightData.battery.maxCellVoltageDelta = extractOptionalField( ...
        batteryMessages, 'max_cell_voltage_delta');
    flightData.battery.fullChargeCapacityWh = extractOptionalField( ...
        batteryMessages, 'full_charge_capacity_wh');
    flightData.battery.remainingCapacityWh = extractOptionalField( ...
        batteryMessages, 'remaining_capacity_wh');
    flightData.battery.nominalVoltage = extractOptionalField( ...
        batteryMessages, 'nominal_voltage');
    flightData.battery.internalResistanceEstimate = ...
        extractOptionalField(batteryMessages, ...
        'internal_resistance_estimate');
    flightData.battery.connected = extractOptionalField( ...
        batteryMessages, 'connected');
    flightData.battery.cellCount = extractOptionalField( ...
        batteryMessages, 'cell_count');
    flightData.battery.isPoweringOff = extractOptionalField( ...
        batteryMessages, 'is_powering_off');
    flightData.battery.warning = extractOptionalField( ...
        batteryMessages, 'warning');
    flightData.battery.faults = extractOptionalField( ...
        batteryMessages, 'faults');
    flightData.battery.voltageUnit = 'V';
    flightData.battery.currentUnit = 'A';
    flightData.battery.capacityUnit = 'mAh';

    flightData.estimatorSelector = createSignalHeader( ...
        'estimator_selector_status', estimatorSelectorInstance, ...
        estimatorSelectorMessages);
    flightData.estimatorSelector.primaryInstance = extractOptionalField( ...
        estimatorSelectorMessages, 'primary_instance');
    flightData.estimatorSelector.instanceChangedCount = ...
        extractOptionalField(estimatorSelectorMessages, ...
        'instance_changed_count');
    flightData.estimatorSelector.healthy = extractOptionalMatrixField( ...
        estimatorSelectorMessages, 'healthy');

    flightData.imuDiagnostics = createSignalHeader( ...
        'vehicle_imu_status', imuStatusInstance, imuStatusMessages);
    flightData.imuDiagnostics.accelVibration = extractOptionalField( ...
        imuStatusMessages, 'accel_vibration_metric');
    flightData.imuDiagnostics.gyroVibration = extractOptionalField( ...
        imuStatusMessages, 'gyro_vibration_metric');
    flightData.imuDiagnostics.coningMetric = extractOptionalField( ...
        imuStatusMessages, 'delta_angle_coning_metric');
    flightData.imuDiagnostics.accelClipping = extractOptionalMatrixField( ...
        imuStatusMessages, 'accel_clipping');
    flightData.imuDiagnostics.gyroClipping = extractOptionalMatrixField( ...
        imuStatusMessages, 'gyro_clipping');
    flightData.imuDiagnostics.accelErrorCount = extractOptionalField( ...
        imuStatusMessages, 'accel_error_count');
    flightData.imuDiagnostics.gyroErrorCount = extractOptionalField( ...
        imuStatusMessages, 'gyro_error_count');
    flightData.imuDiagnostics.meanAccel = extractOptionalMatrixField( ...
        imuStatusMessages, 'mean_accel');
    flightData.imuDiagnostics.meanGyro = extractOptionalMatrixField( ...
        imuStatusMessages, 'mean_gyro');
    flightData.imuDiagnostics.varAccel = extractOptionalMatrixField( ...
        imuStatusMessages, 'var_accel');
    flightData.imuDiagnostics.varGyro = extractOptionalMatrixField( ...
        imuStatusMessages, 'var_gyro');
    flightData.imuDiagnostics.accelDeviceID = extractOptionalField( ...
        imuStatusMessages, 'accel_device_id');
    flightData.imuDiagnostics.gyroDeviceID = extractOptionalField( ...
        imuStatusMessages, 'gyro_device_id');
    flightData.imuDiagnostics.selectionBasis = ...
        'Matches the primary estimator accel_device_id when available';

    flightData.imuConsistency = createSignalHeader( ...
        'sensors_status_imu', imuConsistencyInstance, ...
        imuConsistencyMessages);
    flightData.imuConsistency.accelInconsistency = ...
        extractOptionalMatrixField(imuConsistencyMessages, ...
        'accel_inconsistency_m_s_s');
    flightData.imuConsistency.gyroInconsistency = ...
        extractOptionalMatrixField(imuConsistencyMessages, ...
        'gyro_inconsistency_rad_s');
    flightData.imuConsistency.accelHealthy = ...
        extractOptionalMatrixField(imuConsistencyMessages, ...
        'accel_healthy');
    flightData.imuConsistency.gyroHealthy = ...
        extractOptionalMatrixField(imuConsistencyMessages, ...
        'gyro_healthy');

    flightData.estimatorDiagnostics = createSignalHeader( ...
        'estimator_status', estimatorStatusInstance, ...
        estimatorStatusMessages);
    estimatorFields = { ...
        'posHorizAccuracy', 'pos_horiz_accuracy'; ...
        'posVertAccuracy', 'pos_vert_accuracy'; ...
        'headingTestRatio', 'hdg_test_ratio'; ...
        'velocityTestRatio', 'vel_test_ratio'; ...
        'positionTestRatio', 'pos_test_ratio'; ...
        'heightTestRatio', 'hgt_test_ratio'; ...
        'filterFaultFlags', 'filter_fault_flags'; ...
        'gpsCheckFailFlags', 'gps_check_fail_flags'; ...
        'healthFlags', 'health_flags'; ...
        'timeoutFlags', 'timeout_flags'; ...
        'resetCountVelocityNE', 'reset_count_vel_ne'; ...
        'resetCountVelocityD', 'reset_count_vel_d'; ...
        'resetCountPositionNE', 'reset_count_pos_ne'; ...
        'resetCountPositionD', 'reset_count_pod_d'; ...
        'resetCountQuaternion', 'reset_count_quat'};
    flightData.estimatorDiagnostics = extractNamedFields( ...
        flightData.estimatorDiagnostics, estimatorStatusMessages, ...
        estimatorFields);

    flightData.estimatorInnovations = createSignalHeader( ...
        'estimator_innovations', estimatorInnovationInstance, ...
        estimatorInnovationMessages);
    flightData.estimatorInnovations.gpsHorizontalVelocity = ...
        extractOptionalMatrixField(estimatorInnovationMessages, 'gps_hvel');
    flightData.estimatorInnovations.gpsVerticalVelocity = ...
        extractOptionalField(estimatorInnovationMessages, 'gps_vvel');
    flightData.estimatorInnovations.gpsHorizontalPosition = ...
        extractOptionalMatrixField(estimatorInnovationMessages, 'gps_hpos');
    flightData.estimatorInnovations.gpsVerticalPosition = ...
        extractOptionalField(estimatorInnovationMessages, 'gps_vpos');
    flightData.estimatorInnovations.heading = extractOptionalField( ...
        estimatorInnovationMessages, 'heading');
    flightData.estimatorInnovations.baroVerticalPosition = ...
        extractOptionalField(estimatorInnovationMessages, 'baro_vpos');

    flightData.estimatorTestRatios = createSignalHeader( ...
        'estimator_innovation_test_ratios', estimatorRatioInstance, ...
        estimatorRatioMessages);
    flightData.estimatorTestRatios.gpsHorizontalVelocity = ...
        extractOptionalMatrixField(estimatorRatioMessages, 'gps_hvel');
    flightData.estimatorTestRatios.gpsVerticalVelocity = ...
        extractOptionalField(estimatorRatioMessages, 'gps_vvel');
    flightData.estimatorTestRatios.gpsHorizontalPosition = ...
        extractOptionalMatrixField(estimatorRatioMessages, 'gps_hpos');
    flightData.estimatorTestRatios.gpsVerticalPosition = ...
        extractOptionalField(estimatorRatioMessages, 'gps_vpos');
    flightData.estimatorTestRatios.heading = extractOptionalField( ...
        estimatorRatioMessages, 'heading');
    flightData.estimatorTestRatios.baroVerticalPosition = ...
        extractOptionalField(estimatorRatioMessages, 'baro_vpos');

    flightData.gpsDiagnostics = createSignalHeader( ...
        'vehicle_gps_position', gpsInstance, gpsMessages);
    gpsFields = { ...
        'fixType', 'fix_type'; 'satellitesUsed', 'satellites_used'; ...
        'eph', 'eph'; 'epv', 'epv'; 'hdop', 'hdop'; 'vdop', 'vdop'; ...
        'noisePerMs', 'noise_per_ms'; ...
        'jammingIndicator', 'jamming_indicator'; ...
        'jammingState', 'jamming_state'; ...
        'spoofingState', 'spoofing_state'; ...
        'speedAccuracy', 's_variance_m_s'; ...
        'velocity', 'vel_m_s'; ...
        'velocityNorth', 'vel_n_m_s'; ...
        'velocityEast', 'vel_e_m_s'; ...
        'velocityDown', 'vel_d_m_s'};
    flightData.gpsDiagnostics = extractNamedFields( ...
        flightData.gpsDiagnostics, gpsMessages, gpsFields);

    flightData.geographicPosition = createSignalHeader( ...
        'vehicle_gps_position', gpsInstance, gpsMessages);
    flightData.geographicPosition.latitude = zeros(0, 1);
    flightData.geographicPosition.longitude = zeros(0, 1);
    flightData.geographicPosition.altitudeMSL = zeros(0, 1);
    flightData.geographicPosition.available = false;
    if ~isempty(gpsMessages)
        names = gpsMessages.Properties.VariableNames;
        if all(ismember({'latitude_deg', 'longitude_deg', 'altitude_msl_m'}, names))
            lla = double(gpsMessages{:, {'latitude_deg', 'longitude_deg', 'altitude_msl_m'}});
        elseif all(ismember({'lat', 'lon', 'alt'}, names))
            lla = double(gpsMessages{:, {'lat', 'lon', 'alt'}}) ./ [1e7 1e7 1e3];
        else
            lla = NaN(height(gpsMessages), 3);
        end
        valid = all(isfinite(lla), 2) & abs(lla(:, 1)) <= 90 & ...
            abs(lla(:, 2)) <= 180 & ~(lla(:, 1) == 0 & lla(:, 2) == 0);
        if ismember('fix_type', names)
            valid = valid & double(gpsMessages.fix_type) >= 3;
        end
        lla(~valid, :) = NaN;
        flightData.geographicPosition.latitude = lla(:, 1);
        flightData.geographicPosition.longitude = lla(:, 2);
        flightData.geographicPosition.altitudeMSL = lla(:, 3);
        flightData.geographicPosition.available = any(valid);
    end

    flightData.controlDemand = createSignalHeader( ...
        'vehicle_thrust_setpoint', thrustInstance, thrustMessages);
    flightData.controlDemand.thrust = extractOptionalMatrixField( ...
        thrustMessages, 'xyz');
    flightData.controlDemand.torqueAvailable = ~isempty(torqueMessages);
    flightData.controlDemand.torqueTopicName = 'vehicle_torque_setpoint';
    flightData.controlDemand.torqueInstanceID = torqueInstance;
    flightData.controlDemand.torqueTime = topicTime(torqueMessages);
    flightData.controlDemand.torque = extractOptionalMatrixField( ...
        torqueMessages, 'xyz');

    flightData.manualControl = createSignalHeader( ...
        'manual_control_setpoint', manualControlInstance, ...
        manualControlMessages);
    manualFields = { ...
        'roll', 'roll'; 'pitch', 'pitch'; 'yaw', 'yaw'; ...
        'throttle', 'throttle'; 'valid', 'valid'; ...
        'sticksMoving', 'sticks_moving'; ...
        'dataSource', 'data_source'};
    flightData.manualControl = extractNamedFields( ...
        flightData.manualControl, manualControlMessages, manualFields);

    flightData.rcLink = createSignalHeader( ...
        'input_rc', inputRCInstance, inputRCMessages);
    rcFields = { ...
        'rssi', 'rssi'; 'rssiDbm', 'rssi_dbm'; ...
        'lostFrameCount', 'rc_lost_frame_count'; ...
        'totalFrameCount', 'rc_total_frame_count'; ...
        'failsafe', 'rc_failsafe'; 'lost', 'rc_lost'; ...
        'linkQuality', 'link_quality'};
    flightData.rcLink = extractNamedFields( ...
        flightData.rcLink, inputRCMessages, rcFields);

    flightData.cpuStatus = createSignalHeader( ...
        'cpuload', cpuInstance, cpuMessages);
    flightData.cpuStatus.load = extractOptionalField(cpuMessages, 'load');
    flightData.cpuStatus.ramUsage = extractOptionalField( ...
        cpuMessages, 'ram_usage');

    flightData.radioStatus = createSignalHeader( ...
        'radio_status', radioInstance, radioMessages);
    radioFields = { ...
        'rssi', 'rssi'; 'remoteRssi', 'remote_rssi'; ...
        'noise', 'noise'; 'remoteNoise', 'remote_noise'; ...
        'rxErrors', 'rxerrors'; 'fixedErrors', 'fix'; ...
        'txBuffer', 'txbuf'};
    flightData.radioStatus = extractNamedFields( ...
        flightData.radioStatus, radioMessages, radioFields);

    flightData.telemetryStatus = createSignalHeader( ...
        'telemetry_status', telemetryInstance, telemetryMessages);
    telemetryFields = { ...
        'txRateAverage', 'tx_rate_avg'; ...
        'rxRateAverage', 'rx_rate_avg'; ...
        'txErrorRateAverage', 'tx_error_rate_avg'; ...
        'rxMessageLostCount', 'rx_message_lost_count'; ...
        'rxMessageLostRate', 'rx_message_lost_rate'; ...
        'rxPacketDropCount', 'rx_packet_drop_count'; ...
        'rxParseErrors', 'rx_parse_errors'; ...
        'txBufferOverruns', 'tx_buffer_overruns'; ...
        'rxBufferOverruns', 'rx_buffer_overruns'};
    flightData.telemetryStatus = extractNamedFields( ...
        flightData.telemetryStatus, telemetryMessages, telemetryFields);

    flightData.systemPower = createSignalHeader( ...
        'system_power', systemPowerInstance, systemPowerMessages);
    flightData.systemPower.voltage5V = extractOptionalField( ...
        systemPowerMessages, 'voltage5v_v');
    flightData.systemPower.sensor3V3 = extractOptionalMatrixField( ...
        systemPowerMessages, 'sensors3v3');
    flightData.systemPower.peripheralOverCurrent = ...
        extractOptionalField(systemPowerMessages, 'periph_5v_oc');
    flightData.systemPower.highPowerOverCurrent = ...
        extractOptionalField(systemPowerMessages, 'hipower_5v_oc');

end


function logFile = validateLogFile(logFile)

    if nargin == 0 || isempty(logFile)

        error('FLIP:MissingLogFile', ...
            'A PX4 ULog file path must be provided.');

    end

    if ~(ischar(logFile) || (isstring(logFile) && isscalar(logFile)))

        error('FLIP:InvalidLogFilePath', ...
            'The ULog file path must be a character vector or string scalar.');

    end

    logFile = char(logFile);

    if ~isfile(logFile)

        error('FLIP:FileNotFound', ...
            'The selected ULog file does not exist:\n%s', logFile);

    end

    [~, ~, extension] = fileparts(logFile);

    if ~strcmpi(extension, '.ulg')

        error('FLIP:InvalidFileExtension', ...
            'Select a PX4 ULog file with the .ulg extension.');

    end

end


function validateULogEnvironment()

    if isempty(ver('uav')) || exist('ulogreader', 'file') ~= 2

        error('FLIP:MissingUAVToolbox', [ ...
            'FLIP requires UAV Toolbox to read PX4 ULog files.\n' ...
            'Install UAV Toolbox and run RUNME.m again.']);

    end

    if ~license('test', 'UAV_Toolbox')

        error('FLIP:UAVToolboxLicenseUnavailable', [ ...
            'A UAV Toolbox license is not currently available.\n' ...
            'Check your MATLAB or campus license and try again.']);

    end

end


function instanceID = selectTopicInstance(availableTopics, topicName)

    topicMask = strcmp(string(availableTopics.TopicNames), topicName);

    if ~any(topicMask)

        error('FLIP:MissingRequiredTopic', ...
            'Required PX4 topic "%s" was not found in the selected log.', ...
            topicName);

    end

    instanceIDs = double(availableTopics.InstanceID(topicMask));

    if any(instanceIDs == 0)

        instanceID = 0;

    else

        instanceID = min(instanceIDs);

        warning('FLIP:NonzeroTopicInstance', ...
            'Topic "%s" has no instance 0. FLIP will use instance %d.', ...
            topicName, instanceID);

    end

end


function topicMessages = readRequiredTopic(ulog, topicName, instanceID)

    try

        topicResult = readTopicMsgs(ulog, ...
            'TopicNames', {topicName}, ...
            'InstanceID', {instanceID});

    catch exception

        error('FLIP:TopicReadFailed', [ ...
            'Could not read PX4 topic "%s" (instance %d).\n' ...
            'Reason: %s'], topicName, instanceID, exception.message);

    end

    if isempty(topicResult) || height(topicResult) ~= 1

        error('FLIP:TopicReadFailed', ...
            'PX4 topic "%s" (instance %d) returned no unique result.', ...
            topicName, instanceID);

    end

    topicMessages = topicResult.TopicMessages{1};

    if isempty(topicMessages)

        error('FLIP:EmptyRequiredTopic', ...
            'PX4 topic "%s" (instance %d) contains no messages.', ...
            topicName, instanceID);

    end

end


function [topicMessages, instanceID] = readOptionalTopic( ...
        ulog, topicName, preferredInstance)

    topicMask = strcmp(string(ulog.AvailableTopics.TopicNames), topicName);

    if ~any(topicMask)

        topicMessages = [];
        instanceID = NaN;
        return;

    end

    availableInstances = double( ...
        ulog.AvailableTopics.InstanceID(topicMask));

    if nargin >= 3 && isscalar(preferredInstance) && ...
            isfinite(preferredInstance) && ...
            ismember(preferredInstance, availableInstances)
        instanceID = preferredInstance;
    else
        instanceID = selectTopicInstance(ulog.AvailableTopics, topicName);
    end
    topicMessages = readRequiredTopic(ulog, topicName, instanceID);

end


function [topicMessages, instanceID] = readOptionalTopicMatchingField( ...
        ulog, topicName, fieldName, targetValue)

    topicMask = strcmp(string(ulog.AvailableTopics.TopicNames), topicName);

    if any(topicMask) && isscalar(targetValue) && isfinite(targetValue)
        instanceIDs = double(ulog.AvailableTopics.InstanceID(topicMask));
        for index = 1:numel(instanceIDs)
            candidate = readRequiredTopic( ...
                ulog, topicName, instanceIDs(index));
            if ismember(fieldName, candidate.Properties.VariableNames)
                values = double(candidate.(fieldName)(:));
                if any(isfinite(values) & values == targetValue)
                    topicMessages = candidate;
                    instanceID = instanceIDs(index);
                    return;
                end
            end
        end
    end

    [topicMessages, instanceID] = readOptionalTopic(ulog, topicName);

end


function value = lastFiniteScalarField( ...
        topicMessages, fieldName, fallback)

    value = fallback;
    if isempty(topicMessages) || ...
            ~ismember(fieldName, topicMessages.Properties.VariableNames)
        return;
    end

    candidate = double(topicMessages.(fieldName)(:));
    candidate = candidate(isfinite(candidate));
    if ~isempty(candidate)
        value = candidate(end);
    end

end


function parameterTable = readOptionalParameters(ulog)

    parameterTable = table();

    try
        parameterTable = readParameters(ulog);
    catch exception
        warning('FLIP:ParameterReadFailed', [ ...
            'PX4 parameters could not be read. Actuator outputs will be ' ...
            'shown without verified motor-channel mapping. Reason: %s'], ...
            exception.message);
    end

end


function output = maskUnusedActuatorOutputs(output, nOutputs)

    for sampleIndex = 1:size(output, 1)
        activeCount = floor(nOutputs(sampleIndex));

        if ~isfinite(activeCount)
            output(sampleIndex, :) = NaN;
            continue;
        end

        activeCount = max(0, min(activeCount, size(output, 2)));
        output(sampleIndex, activeCount + 1:end) = NaN;
    end

end


function mapping = buildActuatorOutputMapping( ...
        parameterTable, instanceID, outputWidth)

    mapping = struct( ...
        'available', false, ...
        'source', '', ...
        'outputFunction', nan(1, outputWidth), ...
        'motorNumber', nan(1, outputWidth), ...
        'minimum', nan(1, outputWidth), ...
        'maximum', nan(1, outputWidth), ...
        'disarmed', nan(1, outputWidth));

    if isempty(parameterTable) || ...
            ~all(ismember({'Parameters', 'Values'}, ...
            parameterTable.Properties.VariableNames))
        return;
    end

    switch instanceID
        case 0
            prefix = 'PWM_MAIN';
        case 1
            prefix = 'PWM_AUX';
        otherwise
            return;
    end

    for channelIndex = 1:outputWidth
        suffix = sprintf('%d', channelIndex);
        mapping.outputFunction(channelIndex) = getParameterValue( ...
            parameterTable, sprintf('%s_FUNC%s', prefix, suffix));
        mapping.minimum(channelIndex) = getParameterValue( ...
            parameterTable, sprintf('%s_MIN%s', prefix, suffix));
        mapping.maximum(channelIndex) = getParameterValue( ...
            parameterTable, sprintf('%s_MAX%s', prefix, suffix));
        mapping.disarmed(channelIndex) = getParameterValue( ...
            parameterTable, sprintf('%s_DIS%s', prefix, suffix));
    end

    motorMask = mapping.outputFunction >= 101 & ...
        mapping.outputFunction <= 112;
    mapping.motorNumber(motorMask) = ...
        mapping.outputFunction(motorMask) - 100;
    mapping.available = any(motorMask);

    if mapping.available
        mapping.source = sprintf('%s_FUNCn PX4 parameters', prefix);
    end

end


function value = getParameterValue(parameterTable, parameterName)

    value = NaN;
    rowIndex = find(string(parameterTable.Parameters) == parameterName, ...
        1, 'last');

    if isempty(rowIndex)
        return;
    end

    candidate = parameterTable.Values(rowIndex, :);

    if iscell(candidate)
        candidate = candidate{1};
    end

    candidate = double(candidate);

    if isscalar(candidate) && isfinite(candidate)
        value = candidate;
    end

end


function signal = createSignalHeader(topicName, instanceID, topicMessages)

    signal = struct();
    signal.available = ~isempty(topicMessages);
    signal.topicName = topicName;
    signal.instanceID = instanceID;
    signal.time = zeros(0, 1);

    if signal.available

        signal.time = seconds(topicMessages.Properties.RowTimes(:));

    end

end


function validateTopicFields(topicMessages, requiredFields, topicName)

    availableFields = string(topicMessages.Properties.VariableNames);
    missingFields = requiredFields(~ismember(string(requiredFields), ...
        availableFields));

    if ~isempty(missingFields)

        error('FLIP:MissingRequiredField', ...
            'PX4 topic "%s" is missing required field(s): %s', ...
            topicName, strjoin(missingFields, ', '));

    end

end


function validateVectorWidth(topicMessages, fieldName, expectedWidth, topicName)

    actualWidth = size(topicMessages.(fieldName), 2);

    if actualWidth ~= expectedWidth

        error('FLIP:InvalidVectorWidth', [ ...
            'PX4 topic "%s" field "%s" must contain %d columns. ' ...
            'The selected log contains %d columns.'], ...
            topicName, fieldName, expectedWidth, actualWidth);

    end

end


function value = extractOptionalField(topicMessages, fieldName)

    value = zeros(0, 1);

    if isempty(topicMessages) || ...
            ~ismember(fieldName, topicMessages.Properties.VariableNames)

        return;

    end

    value = double(topicMessages.(fieldName)(:));

end


function value = extractOptionalMatrixField(topicMessages, fieldName)

    value = zeros(0, 0);

    if isempty(topicMessages) || ...
            ~ismember(fieldName, topicMessages.Properties.VariableNames)

        return;

    end

    value = double(topicMessages.(fieldName));

end


function signal = extractNamedFields(signal, topicMessages, mapping)

    for index = 1:size(mapping, 1)
        signal.(mapping{index, 1}) = extractOptionalField( ...
            topicMessages, mapping{index, 2});
    end

end


function time = topicTime(topicMessages)

    time = zeros(0, 1);
    if ~isempty(topicMessages)
        time = seconds(topicMessages.Properties.RowTimes(:));
    end

end


function active = aggregateFailureDetector(topicMessages)

    active = false(0, 1);

    if isempty(topicMessages)

        return;

    end

    sampleCount = height(topicMessages);
    active = false(sampleCount, 1);
    fieldNames = string(topicMessages.Properties.VariableNames);
    detectorFields = fieldNames(startsWith(fieldNames, "fd_"));

    for fieldIndex = 1:numel(detectorFields)

        value = topicMessages.(detectorFields(fieldIndex));

        if isvector(value) && numel(value) == sampleCount

            value = double(value(:));
            active = active | (isfinite(value) & value ~= 0);

        end

    end

    if ismember('motor_failure_mask', ...
            topicMessages.Properties.VariableNames)

        active = active | topicMessages.motor_failure_mask(:) ~= 0;

    end

end
