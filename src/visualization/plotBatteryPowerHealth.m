function figureHandle = plotBatteryPowerHealth(flightData, visibility)
% Plot battery voltage, current, power, energy, charge, and warning evidence.

    if nargin < 2
        visibility = 'on';
    end

    figureHandle = figure( ...
        'Name', 'Battery Power and Health', ...
        'NumberTitle', 'off', ...
        'Color', 'white', ...
        'Position', [100 55 1220 860], ...
        'Visible', visibility);

    if ~hasBatteryData(flightData)
        axesHandle = axes(figureHandle, 'Position', [0.08 0.14 0.84 0.72]);
        axis(axesHandle, 'off');
        text(axesHandle, 0.5, 0.55, ...
            'battery_status data is not available in this log.', ...
            'Units', 'normalized', ...
            'HorizontalAlignment', 'center', ...
            'VerticalAlignment', 'middle', ...
            'FontSize', 12, ...
            'Interpreter', 'none');
        title(axesHandle, 'Battery Power and Health');
        return;
    end

    battery = flightData.battery;
    time = battery.time(:);
    voltage = alignedVector(battery, 'voltage', time);
    current = alignedVector(battery, 'current', time);
    currentAverage = alignedVector(battery, 'currentAverage', time);
    remaining = 100 .* alignedVector(battery, 'remaining', time);
    dischargedMah = alignedVector(battery, 'dischargedMah', time);
    cellCount = alignedVector(battery, 'cellCount', time);
    warningLevel = alignedVector(battery, 'warning', time);
    connected = alignedVector(battery, 'connected', time);
    poweringOff = alignedVector(battery, 'isPoweringOff', time);
    faults = alignedVector(battery, 'faults', time);

    power = voltage .* current;
    energyWh = cumulativeEnergyWh(time, power);
    dischargedRelative = relativeToFirstFinite(dischargedMah);
    equivalentCellVoltage = voltage ./ cellCount;
    equivalentCellVoltage(~isfinite(cellCount) | cellCount < 1) = NaN;
    cellVoltage = validCellVoltageMatrix(battery, numel(time));

    layout = tiledlayout(figureHandle, 3, 2, ...
        'TileSpacing', 'compact', ...
        'Padding', 'compact');
    summaryLines = batterySummary(voltage, current, power, energyWh, ...
        remaining, equivalentCellVoltage, warningLevel);
    title(layout, [{'Battery Power and Health'}, summaryLines], ...
        'Interpreter', 'none', ...
        'Color', [0.10 0.10 0.10]);
    setappdata(figureHandle, 'FLIPBatterySummary', struct( ...
        'powerW', power, ...
        'cumulativeEnergyWh', energyWh, ...
        'equivalentCellVoltageV', equivalentCellVoltage));

    packColor = [0.05 0.35 0.75];
    cellColor = [0.90 0.45 0.05];
    currentColor = [0.75 0.15 0.15];
    averageColor = [0.30 0.30 0.30];
    energyColor = [0.15 0.55 0.25];
    remainingColor = [0.10 0.55 0.25];
    dischargedColor = [0.60 0.25 0.65];

    voltageAxes = nexttile(layout, [1 2]);
    styleAxes(voltageAxes, 'batteryVoltageAxes');
    yyaxis(voltageAxes, 'left');
    packLine = plot(voltageAxes, time, voltage, ...
        'Color', packColor, 'LineWidth', 1.35, ...
        'DisplayName', 'Pack voltage', 'Tag', 'batteryVoltage');
    ylabel(voltageAxes, 'Pack voltage (V)');
    voltageAxes.YAxis(1).Color = packColor;
    hold(voltageAxes, 'on');

    yyaxis(voltageAxes, 'right');
    cellLines = gobjects(0, 1);
    if ~isempty(cellVoltage)
        for cellIndex = 1:size(cellVoltage, 2)
            cellLines(end + 1, 1) = plot(voltageAxes, time, ...
                cellVoltage(:, cellIndex), ...
                'LineWidth', 0.85, ...
                'DisplayName', sprintf('Cell %d', cellIndex), ...
                'Tag', sprintf('batteryCell%d', cellIndex)); %#ok<AGROW>
        end
    elseif any(isfinite(equivalentCellVoltage))
        cellLines = plot(voltageAxes, time, equivalentCellVoltage, '--', ...
            'Color', cellColor, 'LineWidth', 1.15, ...
            'DisplayName', 'Pack/cell estimate', ...
            'Tag', 'batteryCellEquivalent');
    end
    ylabel(voltageAxes, 'Cell voltage (V)');
    voltageAxes.YAxis(2).Color = cellColor;
    title(voltageAxes, ...
        'Voltage (zero-only cell channels are treated as unavailable)', ...
        'Color', [0.10 0.10 0.10]);
    if isempty(cellLines)
        legend(voltageAxes, packLine, 'Location', 'best');
    else
        legend(voltageAxes, [packLine; cellLines(:)], 'Location', 'best');
    end

    currentAxes = nexttile(layout);
    styleAxes(currentAxes, 'batteryCurrentAxes');
    hold(currentAxes, 'on');
    currentLine = plot(currentAxes, time, current, ...
        'Color', currentColor, 'LineWidth', 1.25, ...
        'DisplayName', 'Current', 'Tag', 'batteryCurrent');
    linesForLegend = currentLine;
    if hasUsefulData(currentAverage)
        averageLine = plot(currentAxes, time, currentAverage, '--', ...
            'Color', averageColor, 'LineWidth', 1.05, ...
            'DisplayName', 'Logged average', ...
            'Tag', 'batteryCurrentAverage');
        linesForLegend(end + 1) = averageLine;
    end
    ylabel(currentAxes, 'Current (A)');
    title(currentAxes, 'Battery Current', 'Color', [0.10 0.10 0.10]);
    legend(currentAxes, linesForLegend, 'Location', 'best');

    powerAxes = nexttile(layout);
    styleAxes(powerAxes, 'batteryPowerAxes');
    yyaxis(powerAxes, 'left');
    powerLine = plot(powerAxes, time, power, ...
        'Color', currentColor, 'LineWidth', 1.25, ...
        'DisplayName', 'Electrical power', 'Tag', 'batteryPower');
    ylabel(powerAxes, 'Power (W)');
    powerAxes.YAxis(1).Color = currentColor;
    yyaxis(powerAxes, 'right');
    energyLine = plot(powerAxes, time, energyWh, ...
        'Color', energyColor, 'LineWidth', 1.20, ...
        'DisplayName', 'Integrated energy', 'Tag', 'batteryEnergy');
    ylabel(powerAxes, 'Energy used (Wh)');
    powerAxes.YAxis(2).Color = energyColor;
    title(powerAxes, 'Electrical Power and Integrated Energy', ...
        'Color', [0.10 0.10 0.10]);
    legend(powerAxes, [powerLine energyLine], 'Location', 'best');

    capacityAxes = nexttile(layout);
    styleAxes(capacityAxes, 'batteryCapacityAxes');
    yyaxis(capacityAxes, 'left');
    remainingLine = plot(capacityAxes, time, remaining, ...
        'Color', remainingColor, 'LineWidth', 1.25, ...
        'DisplayName', 'Remaining', 'Tag', 'batteryRemaining');
    ylabel(capacityAxes, 'Remaining (%)');
    capacityAxes.YAxis(1).Color = remainingColor;
    yyaxis(capacityAxes, 'right');
    dischargedLine = plot(capacityAxes, time, dischargedRelative, ...
        'Color', dischargedColor, 'LineWidth', 1.20, ...
        'DisplayName', 'Discharged since log start', ...
        'Tag', 'batteryDischargedMah');
    ylabel(capacityAxes, 'Discharged (mAh)');
    capacityAxes.YAxis(2).Color = dischargedColor;
    title(capacityAxes, 'State of Charge and Discharged Capacity', ...
        'Color', [0.10 0.10 0.10]);
    legend(capacityAxes, [remainingLine dischargedLine], ...
        'Location', 'best');

    statusAxes = nexttile(layout);
    styleAxes(statusAxes, 'batteryStatusAxes');
    hold(statusAxes, 'on');
    statusHandles = gobjects(0, 1);
    if hasUsefulData(warningLevel)
        statusHandles(end + 1) = stairs(statusAxes, time, warningLevel, ...
            'Color', [0.85 0.35 0.05], 'LineWidth', 1.30, ...
            'DisplayName', 'Warning code (raw)', ...
            'Tag', 'batteryWarning');
    end
    warningTop = finiteMaximum(warningLevel, 0);
    markerLevel = max(warningTop + 0.35, 1);
    statusHandles = addStatusMarkers(statusAxes, statusHandles, ...
        time, isfinite(connected) & connected == 0, markerLevel, ...
        [0.80 0.10 0.10], 'Disconnected', 'batteryDisconnected');
    statusHandles = addStatusMarkers(statusAxes, statusHandles, ...
        time, isfinite(faults) & faults ~= 0, markerLevel + 0.35, ...
        [0.55 0.05 0.05], 'Fault flags nonzero', 'batteryFault');
    statusHandles = addStatusMarkers(statusAxes, statusHandles, ...
        time, isfinite(poweringOff) & poweringOff ~= 0, ...
        markerLevel + 0.70, [0.45 0.10 0.55], ...
        'Power-off requested', 'batteryPoweringOff');
    ylim(statusAxes, [-0.25 max(3.5, markerLevel + 1.05)]);
    ylabel(statusAxes, 'Raw status level');
    title(statusAxes, 'Battery Warning and Status', ...
        'Color', [0.10 0.10 0.10]);
    if ~isempty(statusHandles)
        legend(statusAxes, statusHandles, 'Location', 'best');
    else
        text(statusAxes, 0.5, 0.5, 'No finite status fields', ...
            'Units', 'normalized', 'HorizontalAlignment', 'center');
    end

    axesHandles = [voltageAxes; currentAxes; powerAxes; ...
        capacityAxes; statusAxes];
    for index = 1:numel(axesHandles)
        xlabel(axesHandles(index), 'Time from log start (s)');
        yyaxisIfPresent(axesHandles(index), 'left');
    end
    linkaxes(axesHandles, 'x');
    finiteTime = time(isfinite(time));
    if numel(finiteTime) >= 2 && max(finiteTime) > min(finiteTime)
        xlim(voltageAxes, [min(finiteTime) max(finiteTime)]);
    end
    decorateFlightTimeAxes(axesHandles, flightData);
    attachFigureProvenance(figureHandle, { ...
        'Pack voltage', 'battery_status', 'voltage_v', ...
        signalInstance(battery), 'V', 'none', 'Direct', ...
        'Official field and unit; row count matches topic time'; ...
        'Current', 'battery_status', 'current_a', ...
        signalInstance(battery), 'A', 'none', 'Direct', ...
        'Official field and unit; row count matches topic time'; ...
        'Remaining', 'battery_status', 'remaining', ...
        signalInstance(battery), '%', 'multiply logged fraction by 100', ...
        'Converted', 'Official range 0 to 1; synthetic scale test'; ...
        'Discharged since log start', 'battery_status', ...
        'discharged_mah', signalInstance(battery), 'mAh', ...
        'subtract first finite logged sample', 'Converted', ...
        'First-sample offset test'; ...
        'Electrical power', 'battery_status', ...
        'voltage_v, current_a', signalInstance(battery), 'W', ...
        'voltage * current', 'Derived', 'Synthetic product test'; ...
        'Integrated energy', 'battery_status', ...
        'voltage_v, current_a, timestamp', signalInstance(battery), 'Wh', ...
        'gap-aware trapezoidal integration / 3600', 'Derived', ...
        'Synthetic integration and real timestamp checks'; ...
        'Cell-equivalent voltage', 'battery_status', ...
        'voltage_v, cell_count', signalInstance(battery), 'V', ...
        'pack voltage / cell count', 'Derived', ...
        'Explicitly not an individual-cell measurement'; ...
        'Warning/status', 'battery_status', ...
        'warning, connected, faults, is_powering_off', ...
        signalInstance(battery), 'raw enum/bitmask', 'none', 'Direct', ...
        'Raw values retained; no firmware enum guessing'});

end


function value = signalInstance(signal)

    value = NaN;
    if isfield(signal, 'instanceID')
        value = signal.instanceID;
    end

end


function available = hasBatteryData(flightData)

    available = isfield(flightData, 'battery') && ...
        isfield(flightData.battery, 'available') && ...
        flightData.battery.available && ...
        isfield(flightData.battery, 'time') && ...
        ~isempty(flightData.battery.time);

end


function value = alignedVector(signal, fieldName, time)

    value = nan(numel(time), 1);
    if ~isfield(signal, fieldName)
        return;
    end

    candidate = double(signal.(fieldName));
    if isvector(candidate) && numel(candidate) == numel(time)
        value = candidate(:);
    end

end


function value = validCellVoltageMatrix(signal, sampleCount)

    value = zeros(sampleCount, 0);
    if ~isfield(signal, 'cellVoltage')
        return;
    end

    candidate = double(signal.cellVoltage);
    if size(candidate, 1) ~= sampleCount
        return;
    end

    candidate(~isfinite(candidate) | candidate <= 0.5) = NaN;
    candidate = candidate(:, any(isfinite(candidate), 1));
    value = candidate;

end


function energyWh = cumulativeEnergyWh(time, power)

    time = time(:);
    power = power(:);
    energyWh = zeros(size(time));
    positiveStep = diff(time);
    positiveStep = positiveStep(isfinite(positiveStep) & positiveStep > 0);

    if isempty(positiveStep)
        energyWh(:) = NaN;
        return;
    end

    maximumGap = max(1, 5 * median(positiveStep));
    for index = 2:numel(time)
        timeStep = time(index) - time(index - 1);
        energyWh(index) = energyWh(index - 1);
        if isfinite(timeStep) && timeStep > 0 && ...
                timeStep <= maximumGap && ...
                all(isfinite(power(index - 1:index)))
            energyWh(index) = energyWh(index) + ...
                0.5 * sum(power(index - 1:index)) * timeStep / 3600;
        end
    end

end


function value = relativeToFirstFinite(value)

    firstIndex = find(isfinite(value), 1, 'first');
    if ~isempty(firstIndex)
        value = value - value(firstIndex);
    end

end


function styleAxes(axesHandle, tag)

    set(axesHandle, ...
        'Tag', tag, ...
        'Color', 'white', ...
        'XColor', [0.15 0.15 0.15], ...
        'YColor', [0.15 0.15 0.15], ...
        'GridColor', [0.70 0.70 0.70], ...
        'GridAlpha', 0.45);
    grid(axesHandle, 'on');
    box(axesHandle, 'on');

end


function handles = addStatusMarkers(axesHandle, handles, ...
        time, mask, level, color, displayName, tag)

    if any(mask)
        marker = scatter(axesHandle, time(mask), ...
            repmat(level, nnz(mask), 1), 26, color, 'filled', ...
            'DisplayName', displayName, 'Tag', tag);
        handles(end + 1) = marker;
    end

end


function value = finiteMaximum(data, fallback)

    data = data(isfinite(data));
    if isempty(data)
        value = fallback;
    else
        value = max(data);
    end

end


function result = hasUsefulData(value)

    result = ~isempty(value) && any(isfinite(value));

end


function summaryLines = batterySummary(voltage, current, power, energy, ...
        remaining, cellVoltage, warningLevel)

    electricalSummary = sprintf([ ...
        'Pack min %s V | Cell-equivalent min %s V | ' ...
        'Peak current %s A | Peak power %s W'], ...
        formattedFinite(voltage, @min, '%.2f'), ...
        formattedFinite(cellVoltage, @min, '%.2f'), ...
        formattedFinite(current, @max, '%.2f'), ...
        formattedFinite(power, @max, '%.1f'));
    capacitySummary = sprintf([ ...
        'Integrated energy %s Wh | Remaining %s -> %s %% | ' ...
        'Max raw warning %s'], ...
        formattedFinite(energy, @max, '%.3f'), ...
        formattedEndpoint(remaining, 'first', '%.1f'), ...
        formattedEndpoint(remaining, 'last', '%.1f'), ...
        formattedFinite(warningLevel, @max, '%.0f'));
    summaryLines = {electricalSummary, capacitySummary};

end


function textValue = formattedFinite(value, reducer, format)

    value = value(isfinite(value));
    if isempty(value)
        textValue = 'n/a';
    else
        textValue = sprintf(format, reducer(value));
    end

end


function textValue = formattedEndpoint(value, whichEnd, format)

    index = find(isfinite(value), 1, whichEnd);
    if isempty(index)
        textValue = 'n/a';
    else
        textValue = sprintf(format, value(index));
    end

end


function yyaxisIfPresent(axesHandle, side)

    if numel(axesHandle.YAxis) > 1
        yyaxis(axesHandle, side);
    end

end
