function figureHandle = plotMotorCommandVsOutput(flightData, visibility)
% Compare PX4 motor commands with final actuator outputs using verified mappings.

    if nargin < 2
        visibility = 'on';
    end

    figureHandle = figure( ...
        'Name', 'Motor Command vs Final Actuator Output', ...
        'NumberTitle', 'off', ...
        'Color', 'white', ...
        'Position', [120 80 1120 760], ...
        'Visible', visibility);

    [motorCommand, actuatorOutput, pairs, unavailableReason] = ...
        resolveMotorSignals(flightData);

    if isempty(pairs)
        axesHandle = axes(figureHandle, 'Position', [0.08 0.14 0.84 0.72]);
        axis(axesHandle, 'off');
        text(axesHandle, 0.5, 0.55, unavailableReason, ...
            'Units', 'normalized', ...
            'HorizontalAlignment', 'center', ...
            'VerticalAlignment', 'middle', ...
            'FontSize', 12, ...
            'Interpreter', 'none');
        title(axesHandle, 'Motor Command vs Final Actuator Output');
        return;
    end

    pairCount = height(pairs);
    columnCount = min(2, pairCount);
    rowCount = ceil(pairCount / columnCount);
    layout = tiledlayout(figureHandle, rowCount, columnCount, ...
        'TileSpacing', 'compact', ...
        'Padding', 'compact');
    title(layout, { ...
        'Motor Command vs Final Actuator Output', ...
        ['Final output is the flight-controller output, not measured ' ...
         'motor RPM or thrust.']}, ...
        'Interpreter', 'none', ...
        'Color', [0.10 0.10 0.10]);

    commandColor = [0.05 0.35 0.75];
    outputColor = [0.90 0.35 0.05];
    thresholdColor = [0.45 0.45 0.45];
    axesHandles = gobjects(pairCount, 1);

    for pairIndex = 1:pairCount
        motorNumber = pairs.MotorNumber(pairIndex);
        outputChannel = pairs.OutputChannel(pairIndex);
        axesHandles(pairIndex) = nexttile(layout);
        axesHandle = axesHandles(pairIndex);
        set(axesHandle, ...
            'Tag', sprintf('motorComparison%d', motorNumber), ...
            'Color', 'white', ...
            'XColor', [0.15 0.15 0.15], ...
            'GridColor', [0.70 0.70 0.70], ...
            'GridAlpha', 0.45);
        hold(axesHandle, 'on');

        yyaxis(axesHandle, 'left');
        commandLine = plot(axesHandle, motorCommand.time, ...
            motorCommand.control(:, motorNumber), ...
            'Color', commandColor, ...
            'LineWidth', 1.25, ...
            'DisplayName', sprintf('Motor %d command', motorNumber), ...
            'Tag', sprintf('motorCommand%d', motorNumber));
        ylabel(axesHandle, 'Command (normalized)');
        axesHandle.YAxis(1).Color = commandColor;
        commandValues = motorCommand.control(:, motorNumber);

        if any(commandValues < 0)
            ylim(axesHandle, [-1.05 1.05]);
        else
            ylim(axesHandle, [-0.05 1.05]);
        end

        yyaxis(axesHandle, 'right');
        outputLine = plot(axesHandle, actuatorOutput.time, ...
            actuatorOutput.output(:, outputChannel), ...
            'Color', outputColor, ...
            'LineWidth', 1.15, ...
            'DisplayName', sprintf('Output %d raw', outputChannel), ...
            'Tag', sprintf('actuatorOutput%d', outputChannel));
        ylabel(axesHandle, sprintf('Final output (%s)', ...
            actuatorOutput.unit));
        axesHandle.YAxis(2).Color = outputColor;

        minimum = pairs.Minimum(pairIndex);
        maximum = pairs.Maximum(pairIndex);
        disarmed = pairs.Disarmed(pairIndex);
        if isfinite(minimum)
            yline(axesHandle, minimum, ':', thresholdLabel( ...
                pairIndex, 'Configured MIN'), ...
                'Color', thresholdColor, ...
                'LabelVerticalAlignment', 'bottom', ...
                'HandleVisibility', 'off');
        end

        if isfinite(maximum)
            yline(axesHandle, maximum, ':', thresholdLabel( ...
                pairIndex, 'Configured MAX'), ...
                'Color', thresholdColor, ...
                'LabelVerticalAlignment', 'bottom', ...
                'HandleVisibility', 'off');
        end

        if isfinite(disarmed) && ...
                (~isfinite(minimum) || disarmed ~= minimum)
            yline(axesHandle, disarmed, '--', thresholdLabel( ...
                pairIndex, 'Configured DISARMED'), ...
                'Color', [0.55 0.15 0.15], ...
                'LabelVerticalAlignment', 'bottom', ...
                'HandleVisibility', 'off');
        end

        setOutputLimits(axesHandle, ...
            actuatorOutput.output(:, outputChannel), ...
            [minimum maximum disarmed]);
        agreement = calculateShapeAgreement( ...
            motorCommand.time, commandValues, ...
            actuatorOutput.time, ...
            actuatorOutput.output(:, outputChannel), ...
            minimum, maximum);

        if isfinite(agreement)
            agreementText = sprintf(' | active-shape r = %.3f', ...
                agreement);
        else
            agreementText = '';
        end

        title(axesHandle, sprintf( ...
            'Motor %d command -> Output %d%s', ...
            motorNumber, outputChannel, agreementText), ...
            'Interpreter', 'none', ...
            'Color', [0.10 0.10 0.10]);
        grid(axesHandle, 'on');
        box(axesHandle, 'on');
        xlabel(axesHandle, 'Time from log start (s)', ...
            'Color', [0.15 0.15 0.15]);

        if pairIndex == 1
            legend(axesHandle, [commandLine outputLine], ...
                'Location', 'southwest', ...
                'Color', 'white', ...
                'TextColor', [0.10 0.10 0.10], ...
                'EdgeColor', [0.45 0.45 0.45]);
        end

    end

    linkaxes(axesHandles, 'x');
    decorateFlightTimeAxes(axesHandles, flightData);
    attachFigureProvenance(figureHandle, { ...
        'Motor command', 'actuator_motors', 'control', ...
        signalInstance(motorCommand), 'normalized', 'none', 'Direct', ...
        'Finite logged motor channels only'; ...
        'Final actuator output', 'actuator_outputs', 'output', ...
        signalInstance(actuatorOutput), actuatorOutput.unit, 'none', 'Direct', ...
        'Unused channels masked by noutputs'; ...
        'Motor/output mapping', 'ULog parameters', 'PWM_MAIN_FUNCn', ...
        signalInstance(actuatorOutput), 'channel assignment', ...
        'function 101..112 -> motor 1..12', 'Converted', ...
        'No mapping displayed when parameters are unavailable'; ...
        'Active-shape correlation', 'actuator_motors + actuator_outputs', ...
        'control, output', NaN, 'correlation', ...
        'PWM range normalization and timestamp interpolation', 'Derived', ...
        'Signal-path consistency only; not measured RPM or thrust'});

end


function value = signalInstance(signal)

    value = NaN;
    if isfield(signal, 'instanceID')
        value = signal.instanceID;
    end

end


function label = thresholdLabel(pairIndex, textValue)

    label = '';

    if pairIndex == 1
        label = textValue;
    end

end


function [motorCommand, actuatorOutput, pairs, reason] = ...
        resolveMotorSignals(flightData)

    motorCommand = struct();
    actuatorOutput = struct();
    pairs = table();
    reason = ['Motor command or final actuator output is not available ' ...
        'in this log.'];

    if ~isfield(flightData, 'motorCommand') || ...
            ~isfield(flightData, 'actuatorOutput')
        return;
    end

    motorCommand = flightData.motorCommand;
    actuatorOutput = flightData.actuatorOutput;

    if ~isfield(motorCommand, 'available') || ...
            ~motorCommand.available || ...
            ~isfield(actuatorOutput, 'available') || ...
            ~actuatorOutput.available || ...
            isempty(motorCommand.control) || isempty(actuatorOutput.output)
        return;
    end

    if ~isfield(actuatorOutput, 'mappingAvailable') || ...
            ~actuatorOutput.mappingAvailable || ...
            ~isfield(actuatorOutput, 'motorNumber')
        reason = ['Final actuator outputs are available, but PX4 output ' ...
            'function parameters do not provide a verified motor mapping.'];
        return;
    end

    motorNumber = actuatorOutput.motorNumber(:);
    outputChannel = (1:numel(motorNumber)).';
    valid = isfinite(motorNumber) & motorNumber >= 1 & ...
        motorNumber <= size(motorCommand.control, 2) & ...
        outputChannel <= size(actuatorOutput.output, 2);
    motorNumber = motorNumber(valid);
    outputChannel = outputChannel(valid);

    if isempty(motorNumber)
        reason = ['No final actuator output channel is assigned to a ' ...
            'logged motor command.'];
        return;
    end

    commandHasData = false(size(motorNumber));
    outputHasData = false(size(motorNumber));

    for index = 1:numel(motorNumber)
        commandHasData(index) = any(isfinite( ...
            motorCommand.control(:, motorNumber(index))));
        outputHasData(index) = any(isfinite( ...
            actuatorOutput.output(:, outputChannel(index))));
    end

    valid = commandHasData & outputHasData;
    motorNumber = motorNumber(valid);
    outputChannel = outputChannel(valid);

    if isempty(motorNumber)
        reason = 'Verified motor channels contain no finite samples.';
        return;
    end

    minimum = selectMappingValues( ...
        actuatorOutput, 'minimum', outputChannel);
    maximum = selectMappingValues( ...
        actuatorOutput, 'maximum', outputChannel);
    disarmed = selectMappingValues( ...
        actuatorOutput, 'disarmed', outputChannel);
    pairs = table(motorNumber, outputChannel, minimum, maximum, disarmed, ...
        'VariableNames', {'MotorNumber', 'OutputChannel', ...
        'Minimum', 'Maximum', 'Disarmed'});
    pairs = sortrows(pairs, 'MotorNumber');

end


function values = selectMappingValues(signal, fieldName, channel)

    values = nan(size(channel));

    if ~isfield(signal, fieldName)
        return;
    end

    source = signal.(fieldName);
    valid = channel <= numel(source);
    values(valid) = source(channel(valid));

end


function setOutputLimits(axesHandle, output, referenceValues)

    values = [output(isfinite(output)); ...
        referenceValues(isfinite(referenceValues)).'];

    if isempty(values)
        return;
    end

    lower = min(values);
    upper = max(values);
    span = upper - lower;

    if span <= 0
        span = max(abs(lower), 1);
    end

    ylim(axesHandle, [lower - 0.05 * span, upper + 0.05 * span]);

end


function agreement = calculateShapeAgreement( ...
        commandTime, command, outputTime, output, minimum, maximum)

    agreement = NaN;

    if ~isfinite(minimum) || ~isfinite(maximum) || maximum <= minimum
        return;
    end

    commandTime = commandTime(:);
    command = command(:);
    outputTime = outputTime(:);
    output = (output(:) - minimum) ./ (maximum - minimum);
    validOutput = isfinite(outputTime) & isfinite(output);

    if nnz(validOutput) < 2
        return;
    end

    [uniqueTime, uniqueIndex] = unique(outputTime(validOutput), 'stable');
    uniqueOutput = output(validOutput);
    uniqueOutput = uniqueOutput(uniqueIndex);

    if numel(uniqueTime) < 2
        return;
    end

    alignedOutput = interp1(uniqueTime, uniqueOutput, commandTime, ...
        'linear', NaN);
    valid = isfinite(commandTime) & isfinite(command) & ...
        isfinite(alignedOutput) & command > 0.01;

    if nnz(valid) < 3 || std(command(valid)) <= eps || ...
            std(alignedOutput(valid)) <= eps
        return;
    end

    correlation = corrcoef(command(valid), alignedOutput(valid));
    agreement = correlation(1, 2);

end
