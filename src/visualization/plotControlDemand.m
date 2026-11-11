function figureHandle = plotControlDemand(flightData, visibility)
% Plot PX4 normalized thrust and torque references and their vector magnitudes.

    if nargin < 2, visibility = 'on'; end
    figureHandle = figure('Name', 'Control Demand', ...
        'NumberTitle', 'off', 'Color', 'white', ...
        'Position', [100 70 1180 760], 'Visible', visibility);

    if ~isfield(flightData, 'controlDemand') || ...
            ~flightData.controlDemand.available
        ax = axes(figureHandle); axis(ax, 'off');
        text(ax, 0.5, 0.5, ...
            'vehicle_thrust_setpoint is not available in this log.', ...
            'HorizontalAlignment', 'center', 'FontSize', 12);
        return;
    end

    demand = flightData.controlDemand;
    thrust = matrix(demand, 'thrust', demand.time);
    torque = matrix(demand, 'torque', demand.torqueTime);
    layout = tiledlayout(figureHandle, 2, 2, ...
        'TileSpacing', 'compact', 'Padding', 'compact');
    title(layout, {'Normalized Control Demand', ...
        ['Direct PX4 setpoints; vector magnitudes are derived and are not ' ...
        'physical newtons or newton-metres']}, 'Interpreter', 'none', ...
        'Color', [0.10 0.10 0.10]);
    ax = gobjects(4, 1);

    ax(1) = nexttile(layout); style(ax(1), 'thrustComponentsAxes');
    plotComponents(ax(1), demand.time, thrust, ...
        {'X', 'Y', 'Z'}, 'thrustComponent');
    title(ax(1), 'Thrust Setpoint Components');
    ylabel(ax(1), 'Normalized thrust');

    ax(2) = nexttile(layout); style(ax(2), 'thrustMagnitudeAxes');
    plot(ax(2), demand.time, vectorNorm(thrust), 'LineWidth', 1.3, ...
        'Tag', 'thrustMagnitude');
    title(ax(2), 'Thrust Vector Magnitude');
    ylabel(ax(2), 'Normalized magnitude');

    ax(3) = nexttile(layout); style(ax(3), 'torqueComponentsAxes');
    plotComponents(ax(3), demand.torqueTime, torque, ...
        {'Roll/X', 'Pitch/Y', 'Yaw/Z'}, 'torqueComponent');
    title(ax(3), 'Torque Setpoint Components');
    ylabel(ax(3), 'Normalized torque');

    ax(4) = nexttile(layout); style(ax(4), 'torqueMagnitudeAxes');
    plot(ax(4), demand.torqueTime, vectorNorm(torque), ...
        'LineWidth', 1.3, 'Tag', 'torqueMagnitude');
    title(ax(4), 'Torque Vector Magnitude');
    ylabel(ax(4), 'Normalized magnitude');

    for index = 1:numel(ax)
        xlabel(ax(index), 'Time from log start (s)');
    end
    linkaxes(ax, 'x'); setFullTimeLimits(ax(1), flightData);
    decorateFlightTimeAxes(ax, flightData);
    for index = 1:numel(ax), ax(index).Title.Color = [0.10 0.10 0.10]; end
    attachFigureProvenance(figureHandle, { ...
        'Thrust components', 'vehicle_thrust_setpoint', 'xyz', ...
        demand.instanceID, 'normalized', 'none', 'Direct', ...
        'Three columns and topic timestamps checked'; ...
        'Thrust magnitude', 'vehicle_thrust_setpoint', 'xyz', ...
        demand.instanceID, 'normalized', 'sqrt(x^2+y^2+z^2)', ...
        'Derived', 'Synthetic Euclidean-norm test'; ...
        'Torque components', demand.torqueTopicName, 'xyz', ...
        demand.torqueInstanceID, 'normalized', 'none', 'Direct', ...
        'Three columns and independent torque time checked'; ...
        'Torque magnitude', demand.torqueTopicName, 'xyz', ...
        demand.torqueInstanceID, 'normalized', 'sqrt(x^2+y^2+z^2)', ...
        'Derived', 'Synthetic Euclidean-norm test'});

end

function plotComponents(ax, time, values, labels, tagPrefix)
    hold(ax, 'on');
    for column = 1:size(values, 2)
        plot(ax, time, values(:, column), 'LineWidth', 1.05, ...
            'DisplayName', labels{column}, ...
            'Tag', sprintf('%s%d', tagPrefix, column));
    end
    if ~isempty(values), legend(ax, 'Location', 'best'); end
end
function output = vectorNorm(input)
    if isempty(input), output = nan(0, 1); return; end
    output = sqrt(sum(input .^ 2, 2));
    output(any(~isfinite(input), 2)) = NaN;
end
function output = matrix(signal, name, time)
    output = nan(numel(time), 0);
    if isfield(signal, name) && size(signal.(name), 1) == numel(time)
        output = double(signal.(name));
    end
end
function style(ax, tag)
    set(ax, 'Tag', tag, 'Color', 'white', ...
        'XColor', [0.15 0.15 0.15], 'YColor', [0.15 0.15 0.15], ...
        'GridColor', [0.70 0.70 0.70], 'GridAlpha', 0.4);
    hold(ax, 'on'); grid(ax, 'on'); box(ax, 'on');
end
function setFullTimeLimits(ax, data)
    if isfield(data, 'metadata') && isfield(data.metadata, 'duration') && ...
            isfinite(data.metadata.duration) && data.metadata.duration > 0
        xlim(ax, [0 data.metadata.duration]);
    end
end
