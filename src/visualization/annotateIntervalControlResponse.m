function annotateIntervalControlResponse(figureHandle, analysisResult, group)
% Add interval metrics and response landmarks to the logged tracking curves.
    if ~isfield(analysisResult, 'controlResponse') || ~isgraphics(figureHandle, 'figure')
        return;
    end
    groups = {'position', 'velocity', 'attitude', 'rates'};
    names = ["Position", "Velocity", "Attitude", "Angular rate"];
    fields = {{'x','y','z'}, {'vx','vy','vz'}, ...
        {'roll','pitch','yaw'}, {'roll','pitch','yaw'}};
    labels = {{'X','Y','Z'}, {'X','Y','Z'}, ...
        {'Roll','Pitch','Yaw'}, {'Roll','Pitch','Yaw'}};
    index = find(strcmp(groups, group), 1);
    if isempty(index)
        return;
    end
    layout = findobj(figureHandle, 'Tag', 'FLIPTrackingLayout');
    layout.Units = 'normalized';
    layout.OuterPosition = [0 0 0.74 1];
    set(figureHandle, 'Position', [80 50 1600 960]);
    menuTitle = 'Control response';
    if analysisResult.controlResponse.responseMode == "selected"
        menuTitle = 'Interval metrics';
    end
    responseMenu = uimenu(figureHandle, 'Label', menuTitle, 'Tag', 'FLIPResponseMenu');
    summary = analysisResult.controlResponse.summary;
    for axisIndex = 1:3
        ax = findobj(figureHandle, 'Tag', ['FLIPTrackingAxis_' fields{index}{axisIndex}]);
        rows = summary(summary.Signal == names(index) & summary.Axis == string(labels{index}{axisIndex}), :);
        if isempty(ax) || isempty(rows)
            continue;
        end
        setappdata(ax, 'FLIPResponseRows', rows);
        setappdata(ax, 'FLIPResponseIsAngle', strcmp(group, 'attitude'));
        setappdata(ax, 'FLIPResponseOriginalLabel', ax.YLabel.String);
        menu = uimenu(responseMenu, 'Label', labels{index}{axisIndex});
        items = gobjects(height(rows), 1);
        for row = 1:height(rows)
            start = rows.ResponseStart(row);
            if ~isfinite(start)
                start = rows.WindowStart(row);
            end
            items(row) = uimenu(menu, 'Label', sprintf('Response %d | %.3f s', row, start), ...
                'Callback', @(~, ~) selectResponse(ax, row));
        end
        setappdata(ax, 'FLIPResponseMenuItems', items);
        chosen = find(isfinite(rows.RiseTime) | isfinite(rows.SteadyStateError), 1);
        if isempty(chosen)
            chosen = 1;
        end
        selectResponse(ax, chosen);
    end
    setappdata(figureHandle, 'FLIPControlResponse', analysisResult.controlResponse);
end

function selectResponse(ax, index)
    if ~isgraphics(ax, 'axes')
        return;
    end
    delete(findall(ax, '-regexp', 'Tag', '^FLIPResponseOverlay'));
    rows = getappdata(ax, 'FLIPResponseRows');
    row = rows(index, :);
    setappdata(ax, 'FLIPResponseSelection', index);
    items = getappdata(ax, 'FLIPResponseMenuItems');
    set(items(isgraphics(items)), 'Checked', 'off');
    if isgraphics(items(index))
        items(index).Checked = 'on';
    end
    legends = findobj(ancestor(ax, 'figure'), 'Type', 'legend');
    set(legends, 'AutoUpdate', 'off');
    if row.AnalysisMode == "Interval tracking" || ~row.StepDetected
        drawTrackingSummary(ax, row, index, height(rows));
        return;
    end
    if getappdata(ax, 'FLIPResponseIsAngle')
        alignAngularCurves(ax, row);
    end
    xLimits = ax.XLim;
    yLimits = ax.YLim;
    hold(ax, 'on');
    start = row.ResponseStart;
    if ~isfinite(start)
        start = row.WindowStart;
    end
    finish = row.WindowEnd;
    final = row.SteadyStateValue;
    blue = [0.05 0.35 0.75];
    teal = [0 0.48 0.36];
    purple = [0.55 0.12 0.60];
    if all(isfinite([start finish final])) && finish > start
        if isfinite(row.SettlingBand) && row.SettlingBand > 0
            band = patch(ax, [start finish finish start], ...
                final + row.SettlingBand * [-1 -1 1 1], blue, ...
                'FaceAlpha', 0.12, 'EdgeColor', 'none', 'HandleVisibility', 'off', ...
                'HitTest', 'off', 'Tag', 'FLIPResponseOverlayBand');
            uistack(band, 'bottom');
        end
        responseLine(ax, [start finish], [final final], blue, ':', 'Final');
        if isfinite(row.Target)
            responseLine(ax, [max(start, row.TailStart) finish], ...
                [row.Target row.Target], [0.10 0.55 0.20], '--', 'Target');
            if isfinite(row.TailMeanError)
                mid = (max(start, row.TailStart) + finish) / 2;
                errorBase = row.Target - row.TailMeanError;
                errorTip = row.Target;
                if getappdata(ax, 'FLIPResponseIsAngle')
                    shift = 360 * round((final - errorBase)/360);
                    errorBase = errorBase + shift;
                    errorTip = errorTip + shift;
                end
                responseLine(ax, [mid mid], [errorBase errorTip], [0.15 0.15 0.15], '-', 'Error');
                errorLabel = 'tail error';
                if row.SteadyStateAvailable
                    errorLabel = 'e_{ss}';
                end
                text(ax, mid, (errorBase + errorTip)/2, ['  ' errorLabel], ...
                    'FontSize', 10, 'Color', [0.15 0.15 0.15], 'Clipping', 'on', ...
                    'HitTest', 'off', 'Tag', 'FLIPResponseOverlayErrorLabel');
            end
        end
    end
    if all(isfinite([row.RiseStart row.RiseEnd final row.InitialValue]))
        levels = row.InitialValue + [0.1 0.9] * (final - row.InitialValue);
        responseLine(ax, [row.RiseStart row.RiseEnd], [levels(1) levels(1)], blue, '--', 'Rise');
        responseLine(ax, [row.RiseEnd row.RiseEnd], levels, blue, '--', 'RiseEnd');
        plot(ax, [row.RiseStart row.RiseEnd], levels, 'o', 'Color', blue, ...
            'MarkerFaceColor', 'white', 'MarkerSize', 6, 'HandleVisibility', 'off', ...
            'HitTest', 'off', 'Tag', 'FLIPResponseOverlayRisePoints');
        text(ax, (row.RiseStart + row.RiseEnd)/2, levels(1), ' T_r (10-90%)', ...
            'Color', blue, 'FontSize', 10, 'VerticalAlignment', 'top', ...
            'HitTest', 'off', 'Clipping', 'on', 'Tag', 'FLIPResponseOverlayRiseLabel');
    end
    if isfinite(row.SettlingTime) && isfinite(start)
        xline(ax, start + row.SettlingTime, '--', 'T_s', ...
            'Color', teal, 'LineWidth', 1.2, 'LabelVerticalAlignment', 'bottom', ...
            'HandleVisibility', 'off', 'HitTest', 'off', 'Tag', 'FLIPResponseOverlaySettling');
    end
    if all(isfinite([row.PeakAt row.PeakValue row.Overshoot]))
        plot(ax, row.PeakAt, row.PeakValue, 'd', 'Color', purple, ...
            'MarkerFaceColor', purple, 'MarkerSize', 6, 'HandleVisibility', 'off', ...
            'HitTest', 'off', 'Tag', 'FLIPResponseOverlayPeak');
        if isfinite(final)
            responseLine(ax, [row.PeakAt row.PeakAt], [final row.PeakValue], purple, ':', 'Overshoot');
        end
        alignment = 'left';
        if row.PeakAt > xLimits(1) + 0.8 * diff(xLimits)
            alignment = 'right';
        end
        prefix = '';
        if row.FinalValueEstimated
            prefix = '~';
        end
        text(ax, row.PeakAt, row.PeakValue, sprintf(' OS %s%.3g%% ', prefix, row.Overshoot), ...
            'Color', purple, 'FontSize', 10, 'VerticalAlignment', 'bottom', ...
            'HorizontalAlignment', alignment, ...
            'HitTest', 'off', 'Clipping', 'on', 'Tag', 'FLIPResponseOverlayPeakLabel');
    end
    ax.XLim = xLimits;
    ax.YLim = yLimits;
    unit = char(row.ValueUnit);
    estimated = row.FinalValueEstimated;
    settling = metricText(row.SettlingTime, 's', estimated);
    if ~isfinite(row.SettlingTime)
        settling = 'not confirmed';
    end
    errorTitle = 'e_ss (r-y)';
    errorValue = row.SteadyStateError;
    if ~isfinite(errorValue)
        errorTitle = 'Tail mean (r-y)';
        errorValue = row.TailMeanError;
    end
    lines = {sprintf('%s %s | %d/%d', row.Signal, row.Axis, index, height(rows)); ...
        'Detected step'; ...
        ['RMSE ' metricText(row.IntervalRMSE, unit, false) ' | MAE ' metricText(row.IntervalMAE, unit, false)]; ...
        ['Bias ' metricText(row.IntervalBias, unit, false) ' | Max ' metricText(row.IntervalMaxAbsError, unit, false)]; ...
        ['Tr ' metricText(row.RiseTime, 's', estimated) ...
        sprintf(' | Ts(%g%%) ', row.SettlingBandPercent) settling]; ...
        ['OS ' metricText(row.Overshoot, '%', estimated)]; ...
        [errorTitle ': ' metricText(errorValue, unit, ~row.SteadyStateAvailable)]; ...
        ['Final: ' metricText(final, unit, estimated)]};
    if ~row.FinalValueStable && isfinite(final)
        lines{end + 1} = 'Tail moving: estimates, not settled';
    end
    if ~row.ReferenceStable
        lines{end + 1} = 'Reference varying or unavailable';
    end
    if ~row.DataComplete
        lines{end + 1} = 'Gaps: peak is observed-only';
    end
    if ~isfinite(row.RiseTime) && ~isfinite(row.Overshoot) && isfinite(final)
        lines{end + 1} = 'No significant net response change';
        lines{end + 1} = 'Select one transition for Tr / OS';
    end
    if height(rows) > 1
        lines{end + 1} = 'Click here for the next response';
    end
    box = text(ax, 1.025, 0.98, lines, 'Units', 'normalized', ...
        'VerticalAlignment', 'top', 'FontName', 'Segoe UI', 'FontSize', 10.5, ...
        'Color', [0.08 0.12 0.18], 'BackgroundColor', [0.97 0.98 1], ...
        'EdgeColor', [0.68 0.74 0.82], 'Margin', 7, 'Interpreter', 'none', ...
        'Clipping', 'off', 'Tag', 'FLIPResponseOverlaySummary');
    box.ButtonDownFcn = @(~, ~) selectResponse(ax, mod(index, height(rows)) + 1);
end

function drawTrackingSummary(ax, row, index, total)
    xLimits = ax.XLim;
    yLimits = ax.YLim;
    hold(ax, 'on');
    time = rowValue(row, 'TrackingPeakAt');
    actual = rowValue(row, 'TrackingPeakActual');
    reference = rowValue(row, 'TrackingPeakReference');
    if all(isfinite([time actual]))
        if isfinite(reference) && ~getappdata(ax, 'FLIPResponseIsAngle')
            responseLine(ax, [time time], [actual reference], [0.55 0.12 0.60], ':', 'MaxError');
        end
        plot(ax, time, actual, 'd', 'Color', [0.55 0.12 0.60], ...
            'MarkerFaceColor', [0.55 0.12 0.60], 'MarkerSize', 6, ...
            'HandleVisibility', 'off', 'HitTest', 'off', 'Tag', 'FLIPResponseOverlayTrackingPeak');
        alignment = 'left';
        if time > xLimits(1) + 0.8 * diff(xLimits)
            alignment = 'right';
        end
        text(ax, time, actual, sprintf(' max |e| %.3g %s ', row.IntervalMaxAbsError, row.ValueUnit), ...
            'Color', [0.55 0.12 0.60], 'FontSize', 10, ...
            'HorizontalAlignment', alignment, 'VerticalAlignment', 'bottom', ...
            'Clipping', 'on', 'HitTest', 'off', 'Tag', 'FLIPResponseOverlayTrackingPeakLabel');
    end
    unit = char(row.ValueUnit);
    lines = {sprintf('%s %s | interval tracking', row.Signal, row.Axis); ...
        ['RMSE ' metricText(row.IntervalRMSE, unit, false) ' | MAE ' metricText(row.IntervalMAE, unit, false)]; ...
        ['Bias ' metricText(row.IntervalBias, unit, false) ' | Max ' metricText(row.IntervalMaxAbsError, unit, false)]; ...
        ['Std ' metricText(rowValue(row, 'IntervalStdDev'), unit, false) ...
        ' | P95 ' metricText(rowValue(row, 'IntervalP95AbsError'), unit, false)]; ...
        ['IAE ' metricText(rowValue(row, 'IntervalIAE'), rowUnit(row, 'IAEUnit', unit), false)]; ...
        ['ISE ' metricText(rowValue(row, 'IntervalISE'), rowUnit(row, 'ISEUnit', unit), false)]; ...
        ['ITAE ' metricText(rowValue(row, 'IntervalITAE'), rowUnit(row, 'ITAEUnit', unit), false)]; ...
        sprintf('Valid %.4g s | %g samples', rowValue(row, 'IntervalValidDuration'), rowValue(row, 'IntervalSamples')); ...
        ['Tail mean (r-y): ' metricText(row.TailMeanError, unit, true)]};
    if row.AnalysisMode ~= "Interval tracking"
        lines{end + 1} = 'No qualifying command step detected';
    end
    if ~row.DataComplete
        lines{end + 1} = 'Tracking uses available valid segments';
    end
    if total > 1
        lines{end + 1} = 'Click here for the next response';
    end
    label = text(ax, 1.025, 0.98, lines, 'Units', 'normalized', ...
        'VerticalAlignment', 'top', 'FontName', 'Segoe UI', 'FontSize', 10.5, ...
        'Color', [0.08 0.12 0.18], 'BackgroundColor', [0.97 0.98 1], ...
        'EdgeColor', [0.68 0.74 0.82], 'Margin', 7, 'Interpreter', 'none', ...
        'Clipping', 'off', 'Tag', 'FLIPResponseOverlaySummary');
    label.ButtonDownFcn = @(~, ~) selectResponse(ax, mod(index, total) + 1);
    ax.XLim = xLimits;
    ax.YLim = yLimits;
end

function value = rowValue(row, field)
    value = NaN;
    if ismember(field, row.Properties.VariableNames)
        value = row.(field);
    end
end

function unit = rowUnit(row, field, fallback)
    unit = fallback;
    if ismember(field, row.Properties.VariableNames)
        unit = char(row.(field));
    end
end

function responseLine(ax, x, y, color, style, tag)
    plot(ax, x, y, 'Color', color, 'LineStyle', style, 'LineWidth', 1.1, ...
        'HandleVisibility', 'off', 'HitTest', 'off', 'Tag', ['FLIPResponseOverlay' tag]);
end

function textValue = metricText(value, unit, estimated)
    if ~isfinite(value)
        textValue = 'N/A';
        return;
    end
    prefix = '';
    if estimated
        prefix = '~';
    end
    textValue = sprintf('%s%.4g %s', prefix, value, unit);
end

function alignAngularCurves(ax, row)
    traces = findobj(ax, 'Type', 'line');
    changed = false;
    for trace = reshape(traces, 1, [])
        if ~ismember(string(trace.DisplayName), ["Estimated", "Setpoint"])
            continue;
        end
        if ~isappdata(trace, 'FLIPOriginalAngularValues')
            setappdata(trace, 'FLIPOriginalAngularValues', trace.YData);
        end
        original = getappdata(trace, 'FLIPOriginalAngularValues');
        values = original(:);
        finite = isfinite(values);
        starts = find(finite & [true; ~finite(1:end-1)]);
        stops = find(finite & [~finite(2:end); true]);
        for index = 1:numel(starts)
            run = starts(index):stops(index);
            values(run) = rad2deg(unwrap(deg2rad(values(run))));
        end
        initial = row.InitialValue;
        if string(trace.DisplayName) == "Setpoint" && isfinite(row.InitialTarget)
            initial = row.InitialTarget;
        end
        first = find(finite & trace.XData(:) >= row.WindowStart, 1, 'first');
        if row.StepDetected
            first = find(finite & trace.XData(:) < row.StepTime, 1, 'last');
            if isempty(first)
                first = find(finite & trace.XData(:) >= row.StepTime, 1, 'first');
                if string(trace.DisplayName) == "Setpoint" && isfinite(row.Target)
                    initial = row.Target;
                end
            end
        end
        if ~isempty(first) && isfinite(initial)
            values = values + 360 * round((initial - values(first)) / 360);
        end
        originalValues = original(:);
        changed = changed || any(abs(values(finite) - originalValues(finite)) > 1e-8);
        trace.YData = reshape(values, size(original));
    end
    if changed
        ylabel(ax, [char(getappdata(ax, 'FLIPResponseOriginalLabel')) ' (unwrapped)']);
        values = zeros(0, 1);
        for trace = reshape(traces, 1, [])
            if ismember(string(trace.DisplayName), ["Estimated", "Setpoint"])
                values = [values; trace.YData(:)]; %#ok<AGROW>
            end
        end
        values = values(isfinite(values));
        if ~isempty(values)
            limits = [min(values) max(values)];
            margin = max(0.05 * diff(limits), 0.001);
            limits = limits + [-margin margin];
            ax.YLim = limits;
            for shade = reshape(findall(ax, 'Tag', 'flightModeShade'), 1, [])
                y = shade.YData;
                upper = y > (min(y) + max(y))/2;
                y(:) = limits(1);
                y(upper) = limits(2);
                shade.YData = y;
            end
            for label = reshape(findall(ax, 'Tag', 'flightModeLabel'), 1, [])
                label.Position(2) = limits(2) - 0.03 * diff(limits);
            end
        end
    end
end
