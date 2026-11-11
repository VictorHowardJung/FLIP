function decorateFlightTimeAxes(axesHandles, stateSource)
% Add interactive time-axis zoom and flight-mode region shading.

    axesHandles = axesHandles(isgraphics(axesHandles, 'axes'));

    if isempty(axesHandles)
        return;
    end

    axesHandles = sortAxesTopToBottom(axesHandles);
    timeline = extractStateTimeline(stateSource);

    for axesIndex = 1:numel(axesHandles)
        axesHandle = axesHandles(axesIndex);
        configureInteractiveTimeAxis(axesHandle);

        if ~isempty(timeline)
            addModeShading(axesHandle, timeline, axesIndex == 1);
        end
    end

end


function axesHandles = sortAxesTopToBottom(axesHandles)

    verticalPosition = zeros(numel(axesHandles), 1);

    for index = 1:numel(axesHandles)
        previousUnits = axesHandles(index).Units;
        axesHandles(index).Units = 'normalized';
        verticalPosition(index) = axesHandles(index).Position(2);
        axesHandles(index).Units = previousUnits;
    end

    [~, order] = sort(verticalPosition, 'descend');
    axesHandles = axesHandles(order);

end


function timeline = extractStateTimeline(stateSource)

    timeline = table();

    if istable(stateSource)
        candidate = stateSource;
    elseif isstruct(stateSource) && ...
            isfield(stateSource, 'stateTimeline') && ...
            istable(stateSource.stateTimeline)
        candidate = stateSource.stateTimeline;
    else
        return;
    end

    required = {'Time', 'Category', 'State'};

    if isempty(candidate) || ...
            ~all(ismember(required, candidate.Properties.VariableNames))
        return;
    end

    timeline = candidate(candidate.Category == "Flight mode", :);
    timeline = timeline(isfinite(timeline.Time), :);

    if isempty(timeline)
        return;
    end

    timeline = sortrows(timeline, 'Time');
    [~, uniqueIndex] = unique(timeline.Time, 'last');
    timeline = timeline(sort(uniqueIndex), :);

end


function configureInteractiveTimeAxis(axesHandle)

    axesHandle.XTickMode = 'auto';
    axesHandle.XTickLabelMode = 'auto';
    axesHandle.XTickLabelRotation = 0;
    axesHandle.TickDir = 'out';
    setappdata(axesHandle, 'FLIPFullTimeLimits', xlim(axesHandle));
    disableDefaultInteractivity(axesHandle);
    axesHandle.Interactions = [];

    figureHandle = ancestor(axesHandle, 'figure');
    figureHandle.WindowScrollWheelFcn = @(source, event) ...
        zoomFlightTimeAxis(source, event);

end


function addModeShading(axesHandle, timeline, showLabels)

    limits = xlim(axesHandle);
    yLimits = ylim(axesHandle);

    if any(~isfinite([limits yLimits])) || ...
            limits(2) <= limits(1) || yLimits(2) <= yLimits(1)
        return;
    end

    modeStart = timeline.Time(:);
    modeEnd = [modeStart(2:end); limits(2)];
    modeState = string(timeline.State(:));
    holdState = ishold(axesHandle);
    hold(axesHandle, 'on');

    for modeIndex = 1:numel(modeStart)
        startTime = max(modeStart(modeIndex), limits(1));
        endTime = min(modeEnd(modeIndex), limits(2));

        if endTime <= startTime
            continue;
        end

        color = flightModeColor(modeState(modeIndex));
        patch(axesHandle, ...
            [startTime endTime endTime startTime], ...
            [yLimits(1) yLimits(1) yLimits(2) yLimits(2)], ...
            color, ...
            'FaceAlpha', 0.10, ...
            'EdgeColor', 'none', ...
            'HandleVisibility', 'off', ...
            'HitTest', 'off', ...
            'PickableParts', 'none', ...
            'Tag', 'flightModeShade');

        xline(axesHandle, startTime, ':', ...
            'Color', 0.72 .* color, ...
            'LineWidth', 0.7, ...
            'HandleVisibility', 'off', ...
            'Tag', 'flightModeBoundary');

        if showLabels && endTime - startTime >= 0.3
            text(axesHandle, (startTime + endTime) / 2, ...
                yLimits(2) - 0.025 * diff(yLimits), ...
                modeState(modeIndex), ...
                'HorizontalAlignment', 'center', ...
                'VerticalAlignment', 'top', ...
                'FontSize', 7, ...
                'FontWeight', 'bold', ...
                'Color', 0.55 .* color, ...
                'Clipping', 'on', ...
                'HitTest', 'off', ...
                'Tag', 'flightModeLabel');
        end
    end

    if ~holdState
        hold(axesHandle, 'off');
    end

end


function color = flightModeColor(modeState)

    state = lower(strtrim(modeState));

    % Match PX4 Flight Review's official flight_modes_table palette.
    if contains(state, "manual")
        color = [204 0 0] ./ 255;       % #cc0000 red
    elseif contains(state, "altitude")
        color = [238 204 0] ./ 255;     % #eecc00 yellow
    elseif contains(state, "position")
        color = [0 204 51] ./ 255;      % #00cc33 green
    elseif contains(state, "acro")
        color = [102 204 0] ./ 255;     % #66cc00 olive
    elseif contains(state, "offboard")
        color = [0 204 204] ./ 255;     % #00cccc light blue
    elseif contains(state, "stabil")
        color = [0 51 204] ./ 255;      % #0033cc dark blue
    elseif contains(state, "external")
        color = [151 0 204] ./ 255;     % #9700cc violet
    elseif contains(state, "auto") || contains(state, "mission") || ...
            contains(state, "loiter") || contains(state, "rtl") || ...
            contains(state, "descend") || contains(state, "terminat") || ...
            contains(state, "takeoff") || contains(state, "land") || ...
            contains(state, "follow") || contains(state, "orbit")
        color = [102 0 204] ./ 255;     % #6600cc purple
    else
        color = [0.58 0.66 0.72];
    end

end
