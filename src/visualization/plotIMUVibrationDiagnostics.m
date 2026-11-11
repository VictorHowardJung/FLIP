function figureHandle = plotIMUVibrationDiagnostics(flightData, visibility)
% Plot vibration, coning, clipping, and consistency for the selected PX4 IMU.

    if nargin < 2
        visibility = 'on';
    end

    figureHandle = figure('Name', 'IMU Vibration and Consistency', ...
        'NumberTitle', 'off', 'Color', 'white', ...
        'Position', [90 50 1240 860], 'Visible', visibility);

    if ~isAvailable(flightData, 'imuDiagnostics')
        showUnavailable(figureHandle, ...
            'vehicle_imu_status is not available in this log.');
        return;
    end

    imu = flightData.imuDiagnostics;
    time = imu.time(:);
    layout = tiledlayout(figureHandle, 3, 2, ...
        'TileSpacing', 'compact', 'Padding', 'compact');
    title(layout, { ...
        'IMU Vibration and Consistency', ...
        sprintf(['Source: vehicle_imu_status instance %g; selected by ' ...
        'primary estimator accelerometer device when available'], ...
        imu.instanceID)}, 'Interpreter', 'none', 'Color', [0.10 0.10 0.10]);

    axesHandles = gobjects(6, 1);
    axesHandles(1) = nexttile(layout);
    plotSingle(axesHandles(1), time, fieldVector(imu, ...
        'accelVibration', time), 'Accel vibration metric', ...
        'Acceleration vibration (m/s^2)', 'imuAccelVibration');

    axesHandles(2) = nexttile(layout);
    plotSingle(axesHandles(2), time, fieldVector(imu, ...
        'gyroVibration', time), 'Gyro vibration metric', ...
        'Angular-rate vibration (rad/s)', 'imuGyroVibration');

    axesHandles(3) = nexttile(layout);
    plotSingle(axesHandles(3), time, fieldVector(imu, ...
        'coningMetric', time), 'Delta-angle coning metric', ...
        'Coning metric (rad)', 'imuConingMetric');

    axesHandles(4) = nexttile(layout);
    styleAxes(axesHandles(4), 'imuClippingAxes');
    hold(axesHandles(4), 'on');
    accelClipping = rowSum(fieldMatrix(imu, 'accelClipping', time));
    gyroClipping = rowSum(fieldMatrix(imu, 'gyroClipping', time));
    stairs(axesHandles(4), time, accelClipping, 'LineWidth', 1.2, ...
        'DisplayName', 'Accel XYZ total', 'Tag', 'imuAccelClipping');
    stairs(axesHandles(4), time, gyroClipping, 'LineWidth', 1.2, ...
        'DisplayName', 'Gyro XYZ total', 'Tag', 'imuGyroClipping');
    title(axesHandles(4), 'Logged Clipping Counts');
    ylabel(axesHandles(4), 'Count per status sample');
    legend(axesHandles(4), 'Location', 'best');

    axesHandles(5) = nexttile(layout);
    styleAxes(axesHandles(5), 'imuConsistencyAxes');
    consistency = getConsistency(flightData);
    yyaxis(axesHandles(5), 'left');
    accelInconsistency = rowMaximum(consistency.accel);
    plot(axesHandles(5), consistency.time, accelInconsistency, ...
        'LineWidth', 1.2, 'DisplayName', 'Accel max', ...
        'Tag', 'imuAccelInconsistency');
    ylabel(axesHandles(5), 'Accel inconsistency (m/s^2)');
    yyaxis(axesHandles(5), 'right');
    gyroInconsistency = rowMaximum(consistency.gyro);
    plot(axesHandles(5), consistency.time, gyroInconsistency, ...
        'LineWidth', 1.2, 'DisplayName', 'Gyro max', ...
        'Tag', 'imuGyroInconsistency');
    ylabel(axesHandles(5), 'Gyro inconsistency (rad/s)');
    title(axesHandles(5), 'Maximum Inter-IMU Inconsistency');

    axesHandles(6) = nexttile(layout);
    styleAxes(axesHandles(6), 'imuErrorAxes');
    hold(axesHandles(6), 'on');
    stairs(axesHandles(6), time, fieldVector(imu, ...
        'accelErrorCount', time), 'LineWidth', 1.2, ...
        'DisplayName', 'Accel errors', 'Tag', 'imuAccelErrors');
    stairs(axesHandles(6), time, fieldVector(imu, ...
        'gyroErrorCount', time), 'LineWidth', 1.2, ...
        'DisplayName', 'Gyro errors', 'Tag', 'imuGyroErrors');
    title(axesHandles(6), 'Cumulative Sensor Error Counters');
    ylabel(axesHandles(6), 'Cumulative count');
    legend(axesHandles(6), 'Location', 'best');

    finalizeAxes(axesHandles, flightData);
    attachFigureProvenance(figureHandle, { ...
        'Accel vibration', 'vehicle_imu_status', ...
        'accel_vibration_metric', imu.instanceID, 'm/s^2', ...
        'none', 'Direct', 'Field exists; row count matches topic time'; ...
        'Gyro vibration', 'vehicle_imu_status', ...
        'gyro_vibration_metric', imu.instanceID, 'rad/s', ...
        'none', 'Direct', 'Field exists; row count matches topic time'; ...
        'Coning metric', 'vehicle_imu_status', ...
        'delta_angle_coning_metric', imu.instanceID, 'rad', ...
        'none', 'Direct', 'Field exists; row count matches topic time'; ...
        'Clipping total', 'vehicle_imu_status', ...
        'accel_clipping, gyro_clipping', imu.instanceID, 'count', ...
        'sum XYZ columns', 'Derived', 'Synthetic row-sum test'; ...
        'IMU inconsistency', 'sensors_status_imu', ...
        'accel_inconsistency_m_s_s, gyro_inconsistency_rad_s', ...
        consistency.instanceID, 'm/s^2; rad/s', ...
        'maximum finite sensor channel', 'Derived', ...
        'Field dimensions and source time checked'; ...
        'Sensor errors', 'vehicle_imu_status', ...
        'accel_error_count, gyro_error_count', imu.instanceID, 'count', ...
        'none', 'Direct', 'Field exists; row count matches topic time'});

end


function plotSingle(ax, time, value, plotTitle, yLabel, tag)
    styleAxes(ax, [tag 'Axes']);
    plot(ax, time, value, 'LineWidth', 1.25, 'Tag', tag);
    title(ax, plotTitle); ylabel(ax, yLabel);
end

function consistency = getConsistency(flightData)
    consistency = struct('time', zeros(0, 1), 'accel', zeros(0, 0), ...
        'gyro', zeros(0, 0), 'instanceID', NaN);
    if ~isAvailable(flightData, 'imuConsistency'), return; end
    signal = flightData.imuConsistency;
    consistency.time = signal.time(:);
    consistency.accel = fieldMatrix(signal, ...
        'accelInconsistency', consistency.time);
    consistency.gyro = fieldMatrix(signal, ...
        'gyroInconsistency', consistency.time);
    consistency.instanceID = signal.instanceID;
end

function value = fieldVector(signal, name, time)
    value = nan(numel(time), 1);
    if isfield(signal, name) && numel(signal.(name)) == numel(time)
        value = double(signal.(name)(:));
    end
end

function value = fieldMatrix(signal, name, time)
    value = nan(numel(time), 0);
    if isfield(signal, name) && size(signal.(name), 1) == numel(time)
        value = double(signal.(name));
    end
end

function value = rowSum(matrix)
    if isempty(matrix), value = nan(0, 1); return; end
    value = sum(matrix, 2, 'omitnan');
    value(all(~isfinite(matrix), 2)) = NaN;
end

function value = rowMaximum(matrix)
    if isempty(matrix), value = nan(0, 1); return; end
    value = max(matrix, [], 2, 'omitnan');
    value(all(~isfinite(matrix), 2)) = NaN;
end

function result = isAvailable(data, fieldName)
    result = isfield(data, fieldName) && ...
        isfield(data.(fieldName), 'available') && data.(fieldName).available;
end

function styleAxes(ax, tag)
    set(ax, 'Tag', tag, 'Color', 'white', ...
        'XColor', [0.15 0.15 0.15], 'YColor', [0.15 0.15 0.15], ...
        'GridColor', [0.70 0.70 0.70], 'GridAlpha', 0.4);
    hold(ax, 'on'); grid(ax, 'on'); box(ax, 'on');
end

function finalizeAxes(axesHandles, flightData)
    for index = 1:numel(axesHandles)
        xlabel(axesHandles(index), 'Time from log start (s)');
        if numel(axesHandles(index).YAxis) > 1, yyaxis(axesHandles(index), 'left'); end
    end
    linkaxes(axesHandles, 'x'); setFullTimeLimits(axesHandles(1), flightData);
    decorateFlightTimeAxes(axesHandles, flightData);
    for index = 1:numel(axesHandles), axesHandles(index).Title.Color = [0.10 0.10 0.10]; end
end

function setFullTimeLimits(ax, data)
    if isfield(data, 'metadata') && isfield(data.metadata, 'duration') && ...
            isfinite(data.metadata.duration) && data.metadata.duration > 0
        xlim(ax, [0 data.metadata.duration]);
    end
end

function showUnavailable(figureHandle, message)
    ax = axes(figureHandle); axis(ax, 'off');
    text(ax, 0.5, 0.5, message, 'HorizontalAlignment', 'center', ...
        'Interpreter', 'none', 'FontSize', 12);
end
