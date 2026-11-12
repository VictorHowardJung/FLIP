function figureHandle = createIntervalAnalysisWindow(flightData, visibility, options)
% Create an interactive flight-interval analysis window.

    arguments
        flightData (1, 1) struct
        visibility (1, 1) string {mustBeMember(visibility, ["on", "off"])} = "on"
        options.PlotVisibility (1, 1) string ...
            {mustBeMember(options.PlotVisibility, ["on", "off"])} = visibility
        options.OutputSession (1, 1) struct = struct()
    end

    outputSession = options.OutputSession;
    colors = intervalWindowColors();
    [availableStart, availableEnd] = trajectoryTimeRange(flightData);
    positionTimes = unique(flightData.position.time( ...
        isfinite(flightData.position.time)));
    pickingBoundary = "";
    analysisClock = [];

    figureHandle = figure( ...
        'Name', 'FLIP Interval Re-analysis', ...
        'NumberTitle', 'off', ...
        'Color', colors.window, ...
        'MenuBar', 'none', ...
        'ToolBar', 'figure', ...
        'Position', [60, 70, 1440, 840], ...
        'Visible', visibility);
    if isprop(figureHandle, 'Theme')
        figureHandle.Theme = 'light';
    end
    if visibility == "on"
        figureHandle.WindowState = 'maximized';
    end

    overviewAxes = axes( ...
        'Parent', figureHandle, ...
        'Units', 'normalized', ...
        'Position', [0.065, 0.56, 0.55, 0.37]);
    plotOverview(overviewAxes, flightData);
    overviewAxes.Tag = 'intervalOverviewAxes';
    drawStateBoundaries(overviewAxes, flightData);
    decorateFlightTimeAxes(overviewAxes, flightData);

    rightTabs = uitabgroup(figureHandle, ...
        'Units', 'normalized', ...
        'Position', [0.65, 0.40, 0.33, 0.54]);
    stateTab = uitab(rightTabs, 'Title', 'State boundaries');
    intervalTab = uitab(rightTabs, 'Title', 'Saved intervals');
    createStateTable(stateTab, flightData);
    [intervalTable, intervalButtons] = createIntervalTable(intervalTab);
    intervals = emptyIntervalTable();
    selectedRows = zeros(0, 1);

    responsePanel = uipanel(figureHandle, 'BorderType', 'none', ...
        'Units', 'normalized', 'Position', [0.065 0.425 0.55 0.065], ...
        'BackgroundColor', colors.window, 'Tag', 'responseSettingsPanel');
    uicontrol(responsePanel, 'Style', 'text', 'Units', 'normalized', ...
        'Position', [0 0.56 0.23 0.40], 'HorizontalAlignment', 'left', ...
        'String', 'Response basis:');
    responseMode = uicontrol(responsePanel, 'Style', 'popupmenu', ...
        'Units', 'normalized', 'Position', [0.24 0.54 0.76 0.44], ...
        'String', {'Interval tracking (selected window)', 'Detected command-step response'}, ...
        'Value', 1, 'Tag', 'responseAnalysisMode', ...
        'TooltipString', 'Use tracking errors for general intervals; transient metrics require a detected command step.');
    responseCaption = uicontrol(responsePanel, 'Style', 'text', 'Units', 'normalized', ...
        'Position', [0 0.02 0.48 0.40], 'HorizontalAlignment', 'left', ...
        'String', 'Tracking: RMSE / MAE / bias / max');
    settlingBand = uicontrol(responsePanel, 'Style', 'popupmenu', ...
        'Units', 'normalized', 'Position', [0.48 0.01 0.20 0.44], ...
        'String', {'+/-2%', '+/-5%'}, 'Value', 1, 'Visible', 'off', ...
        'Tag', 'responseSettlingBand', ...
        'TooltipString', 'Band around estimated steady output, relative to steady output minus initial actual.');
    tailCaption = uicontrol(responsePanel, 'Style', 'text', 'Units', 'normalized', ...
        'Position', [0.72 0.02 0.28 0.40], 'HorizontalAlignment', 'left', ...
        'String', 'Error tail: 20%');

    pickStartButton = uicontrol(figureHandle, ...
        'Style', 'togglebutton', 'String', 'Pick start', ...
        'Units', 'normalized', 'Position', [0.065, 0.385, 0.12, 0.035], ...
        'TooltipString', 'Click the plot to select start, then end. Esc cancels.', ...
        'Tag', 'pickIntervalStart');
    pickEndButton = uicontrol(figureHandle, ...
        'Style', 'togglebutton', 'String', 'Pick end', ...
        'Units', 'normalized', 'Position', [0.195, 0.385, 0.12, 0.035], ...
        'TooltipString', 'Click the plot to adjust only the end time. Esc cancels.', ...
        'Tag', 'pickIntervalEnd');
    uicontrol(figureHandle, 'Style', 'text', ...
        'String', 'Select times on the overview or type them below.', ...
        'HorizontalAlignment', 'left', 'Units', 'normalized', ...
        'Position', [0.33, 0.385, 0.30, 0.032]);

    selectionPanel = uipanel(figureHandle, ...
        'Title', 'Select an interval', 'Units', 'normalized', ...
        'Position', [0.04, 0.245, 0.94, 0.12], ...
        'BackgroundColor', 'white', 'BorderType', 'line', ...
        'HighlightColor', colors.border, 'Tag', 'intervalSelectionPanel');

    uicontrol(selectionPanel, ...
        'Style', 'text', ...
        'String', 'Interval label', ...
        'BackgroundColor', 'white', ...
        'HorizontalAlignment', 'left', ...
        'Units', 'normalized', ...
        'FontWeight', 'bold', ...
        'Position', [0.015, 0.29, 0.095, 0.35]);
    labelEdit = uicontrol(selectionPanel, ...
        'Style', 'edit', ...
        'String', 'Selected interval', ...
        'BackgroundColor', 'white', ...
        'HorizontalAlignment', 'left', ...
        'Units', 'normalized', ...
        'Position', [0.115, 0.16, 0.25, 0.60], ...
        'Tag', 'intervalLabel');

    uicontrol(selectionPanel, ...
        'Style', 'text', ...
        'String', 'Start (s)', ...
        'BackgroundColor', 'white', ...
        'HorizontalAlignment', 'left', ...
        'Units', 'normalized', ...
        'FontWeight', 'bold', ...
        'Position', [0.38, 0.29, 0.075, 0.35]);
    startEdit = uicontrol(selectionPanel, ...
        'Style', 'edit', ...
        'String', sprintf('%.6f', availableStart), ...
        'UserData', availableStart, ...
        'BackgroundColor', 'white', ...
        'Units', 'normalized', ...
        'Position', [0.46, 0.16, 0.10, 0.60], ...
        'Tag', 'intervalStart');

    uicontrol(selectionPanel, ...
        'Style', 'text', ...
        'String', 'End (s)', ...
        'BackgroundColor', 'white', ...
        'HorizontalAlignment', 'left', ...
        'Units', 'normalized', ...
        'FontWeight', 'bold', ...
        'Position', [0.58, 0.29, 0.06, 0.35]);
    endEdit = uicontrol(selectionPanel, ...
        'Style', 'edit', ...
        'String', sprintf('%.6f', availableEnd), ...
        'UserData', availableEnd, ...
        'BackgroundColor', 'white', ...
        'Units', 'normalized', ...
        'Position', [0.65, 0.16, 0.10, 0.60], ...
        'Tag', 'intervalEnd');

    analyzeButton = uicontrol(selectionPanel, ...
        'Style', 'pushbutton', ...
        'String', 'Add & analyze', ...
        'Units', 'normalized', ...
        'Position', [0.78, 0.16, 0.20, 0.60], ...
        'FontWeight', 'bold', ...
        'BusyAction', 'cancel', ...
        'Tag', 'analyzeIntervalButton');

    statusPanel = uipanel(figureHandle, ...
        'Title', 'Analysis status', 'Units', 'normalized', ...
        'Position', [0.04, 0.065, 0.94, 0.16], ...
        'BackgroundColor', 'white', 'BorderType', 'line', ...
        'HighlightColor', colors.border, 'Tag', 'intervalStatusPanel');
    statusText = uicontrol(statusPanel, ...
        'Style', 'text', ...
        'String', sprintf( ...
            'Available trajectory range: %.3f to %.3f s', ...
            availableStart, availableEnd), ...
        'BackgroundColor', 'white', ...
        'HorizontalAlignment', 'left', ...
        'Units', 'normalized', ...
        'Position', [0.015, 0.08, 0.97, 0.72], ...
        'Tag', 'intervalStatus');

    instructionText = [ ...
        'Pick start, then click the plot for start and end. ' ...
        'Pick end adjusts only the end. Esc cancels. Times are relative to log start.'];
    uicontrol(figureHandle, ...
        'Style', 'text', ...
        'String', instructionText, ...
        'BackgroundColor', 'white', ...
        'HorizontalAlignment', 'left', ...
        'Units', 'normalized', ...
        'Position', [0.05, 0.012, 0.90, 0.032], ...
        'Tag', 'intervalInstructions');

    styleIntervalWindow(figureHandle, colors);
    startMarker = xline(overviewAxes, availableStart, '-', 'Start', ...
        'Color', [0.00, 0.40, 0.26], 'LineWidth', 1.8, ...
        'LabelOrientation', 'horizontal', 'LabelVerticalAlignment', 'bottom', ...
        'LabelHorizontalAlignment', 'left', 'FontName', 'Segoe UI', ...
        'FontSize', 11, 'FontWeight', 'bold', ...
        'HandleVisibility', 'off', 'Tag', 'intervalStartMarker');
    endMarker = xline(overviewAxes, availableEnd, '-', 'End', ...
        'Color', [0.75, 0.22, 0.05], 'LineWidth', 1.8, ...
        'LabelOrientation', 'horizontal', 'LabelVerticalAlignment', 'bottom', ...
        'LabelHorizontalAlignment', 'right', 'FontName', 'Segoe UI', ...
        'FontSize', 11, 'FontWeight', 'bold', ...
        'HandleVisibility', 'off', 'Tag', 'intervalEndMarker');
    for child = reshape(allchild(overviewAxes), 1, [])
        if isprop(child, 'HitTest')
            child.HitTest = 'off';
        end
        if isprop(child, 'PickableParts')
            child.PickableParts = 'none';
        end
    end
    overviewAxes.PickableParts = 'all';
    overviewAxes.ButtonDownFcn = @pickTimeFromOverview;
    figureHandle.WindowKeyPressFcn = @cancelPickingWithEscape;
    pickStartButton.Callback = @(source, ~) togglePicking(source, "start");
    pickEndButton.Callback = @(source, ~) togglePicking(source, "end");
    startEdit.Callback = @editBoundaryTime;
    endEdit.Callback = @editBoundaryTime;

    analyzeButton.Callback = @addAndAnalyzeInterval;
    intervalTable.CellSelectionCallback = @selectIntervalRows;
    intervalButtons.analyze.Callback = @analyzeSavedInterval;
    intervalButtons.split.Callback = @splitSavedInterval;
    intervalButtons.merge.Callback = @mergeSavedIntervals;
    intervalButtons.delete.Callback = @deleteSavedIntervals;
    busyControls = [pickStartButton, pickEndButton, labelEdit, startEdit, endEdit, settlingBand, responseMode, ...
        analyzeButton, intervalButtons.analyze, intervalButtons.split, ...
        intervalButtons.merge, intervalButtons.delete];
    set([analyzeButton, intervalButtons.analyze], 'BusyAction', 'cancel');
    setappdata(figureHandle, 'IntervalAnalysisBusy', false);
    responseMode.Callback = @updateResponseMode;

    function updateResponseMode(~, ~)
        if isAnalysisRunning()
            return;
        end
        if responseMode.Value == 1
            responseCaption.String = 'Tracking: RMSE / MAE / bias / max';
            settlingBand.Visible = 'off';
            tailCaption.String = 'Error tail: 20%';
        else
            responseCaption.String = 'Rise: 10-90%  |  Settling band:';
            settlingBand.Visible = 'on';
            tailCaption.String = 'Steady tail: 20%';
        end
    end

    function togglePicking(source, boundary)
        if isAnalysisRunning()
            return;
        end
        if source.Value == 0
            setPickingBoundary("");
            showStatus('Time selection canceled. Existing times are retained.', false);
            return;
        end
        setPickingBoundary(boundary);
        if boundary == "start"
            showStatus('Click the overview for start, then end. Esc cancels.', false);
        else
            showStatus('Click the overview for the end time. Esc cancels.', false);
        end
    end

    function setPickingBoundary(boundary)
        pickingBoundary = boundary;
        set(pickStartButton, 'Value', boundary == "start", ...
            'BackgroundColor', colors.button, 'ForegroundColor', colors.text);
        set(pickEndButton, 'Value', boundary == "end", ...
            'BackgroundColor', colors.button, 'ForegroundColor', colors.text);
        if boundary == ""
            figureHandle.Pointer = 'arrow';
            return;
        end
        zoom(figureHandle, 'off');
        pan(figureHandle, 'off');
        rotate3d(figureHandle, 'off');
        datacursormode(figureHandle, 'off');
        figureHandle.Pointer = 'crosshair';
        if boundary == "start"
            activeButton = pickStartButton;
        else
            activeButton = pickEndButton;
        end
        set(activeButton, 'BackgroundColor', colors.primary, ...
            'ForegroundColor', [1 1 1]);
    end

    function pickTimeFromOverview(~, event)
        if isAnalysisRunning() || pickingBoundary == ""
            return;
        end
        if (isstruct(event) && isfield(event, 'Button')) || ...
                (isobject(event) && isprop(event, 'Button'))
            if event.Button ~= 1
                return;
            end
        elseif ~strcmp(figureHandle.SelectionType, 'normal')
            return;
        end
        if (isstruct(event) && isfield(event, 'IntersectionPoint')) || ...
                (isobject(event) && isprop(event, 'IntersectionPoint'))
            point = event.IntersectionPoint;
        else
            point = overviewAxes.CurrentPoint(1, :);
        end
        if isempty(point) || ~isfinite(point(1))
            return;
        end
        [~, index] = min(abs(positionTimes - point(1)));
        selectedTime = positionTimes(index);
        if pickingBoundary == "start"
            if selectedTime >= availableEnd
                showStatus('Start must precede the final position sample. Click again.', true);
                return;
            end
            setBoundaryTime(startEdit, selectedTime);
            updateSelectionMarkers();
            setPickingBoundary("end");
            showStatus(sprintf( ...
                'Start: %.6f s. Click later on the overview for end. Esc cancels.', ...
                selectedTime), false);
        else
            startTime = readBoundaryTime(startEdit);
            if ~isfinite(startTime) || startTime < availableStart || ...
                    startTime >= availableEnd
                showStatus('Enter or pick a valid start time first.', true);
                return;
            end
            if selectedTime <= startTime
                showStatus('End must be later than start. Click again or press Esc.', true);
                return;
            end
            setBoundaryTime(endEdit, selectedTime);
            updateSelectionMarkers();
            setPickingBoundary("");
            showStatus(sprintf( ...
                'Selected %.6f to %.6f s. Click Add & analyze to analyze this interval.', ...
                startTime, selectedTime), false);
        end
    end

    function cancelPickingWithEscape(~, event)
        if isAnalysisRunning()
            return;
        end
        if strcmp(event.Key, 'escape') && pickingBoundary ~= ""
            setPickingBoundary("");
            showStatus('Time selection canceled. Existing times are retained.', false);
        end
    end

    function editBoundaryTime(source, ~)
        if isAnalysisRunning()
            return;
        end
        source.UserData = [];
        setPickingBoundary("");
        updateSelectionMarkers();
    end

    function updateSelectionMarkers()
        updateMarker(startMarker, readBoundaryTime(startEdit));
        updateMarker(endMarker, readBoundaryTime(endEdit));
    end

    function updateMarker(marker, time)
        if isfinite(time) && time >= availableStart && time <= availableEnd
            marker.Value = time;
            marker.Visible = 'on';
        else
            marker.Visible = 'off';
        end
    end

    function addAndAnalyzeInterval(~, ~)

        if isAnalysisRunning()
            return;
        end
        setPickingBoundary("");
        updateSelectionMarkers();
        startTime = readBoundaryTime(startEdit);
        endTime = readBoundaryTime(endEdit);
        label = labelEdit.String;
        analyzeInterval(startTime, endTime, label, true);

    end


    function analyzeSavedInterval(~, ~)

        if isAnalysisRunning()
            return;
        end
        if numel(selectedRows) ~= 1

            showStatus('Select one saved interval to analyze.', true);
            return;

        end

        selected = intervals(selectedRows, :);
        analyzeInterval(selected.StartTime, selected.EndTime, ...
            char(selected.Label), false);

    end


    function analyzeInterval(startTime, endTime, label, addToTable)

        if isAnalysisRunning() || ~isgraphics(figureHandle, 'figure')
            return;
        end
        setPickingBoundary("");
        analysisClock = tic;
        setappdata(figureHandle, 'IntervalAnalysisBusy', true);
        setappdata(figureHandle, 'LatestIntervalError', []);
        cleanupAnalysis = onCleanup(@() restoreIntervalAnalysisControls( ...
            figureHandle, busyControls, analyzeButton, intervalTable));
        set(busyControls, 'Enable', 'off');
        intervalTable.Enable = 'off';
        figureHandle.Pointer = 'watch';
        showAnalysisProgress("metrics", 0, 1, "Calculating interval metrics");

        try

            thresholds = [0.02 0.05];
            modes = ["selected", "detected"];
            [intervalData, intervalResult] = reanalyzeFlightInterval( ...
                flightData, startTime, endTime, label, ...
                SettlingThreshold=thresholds(settlingBand.Value), ResponseMode=modes(responseMode.Value));
            if ~isgraphics(figureHandle, 'figure')
                return;
            end

            if addToTable

                intervals = [intervals; createFlightIntervalDefinition( ...
                    startTime, endTime, label)];
                intervals = sortrows(intervals, {'StartTime', 'EndTime'});
                selectedRows = zeros(0, 1);
                refreshIntervalTable();

            end

            setappdata(figureHandle, 'LatestIntervalData', intervalData);
            setappdata(figureHandle, 'LatestIntervalResult', intervalResult);
            if isempty(fieldnames(outputSession))
                outputSession = createAnalysisOutputSession();
            end
            outputDirectory = createUniqueOutputDirectory( ...
                outputSession.intervalDirectory, ...
                sprintf('interval_%.6fs_%.6fs', startTime, endTime));
            sourceLog = intervalData.fileName;
            if isfield(intervalData.metadata, 'sourceFile')
                sourceLog = intervalData.metadata.sourceFile;
            end
            [intervalFigures, savedFiles, combinedPdfFile] = ...
                outputFlightAnalysis(intervalData, intervalResult, ...
                    sourceLog, outputDirectory, options.PlotVisibility, ...
                    ProgressFcn=@showAnalysisProgress);
            if ~isgraphics(figureHandle, 'figure')
                return;
            end
            setappdata(figureHandle, 'LatestIntervalFigures', intervalFigures);
            setappdata(figureHandle, 'LatestIntervalOutputDirectory', outputDirectory);
            setappdata(figureHandle, 'LatestIntervalFigureFiles', savedFiles);
            setappdata(figureHandle, 'LatestIntervalPdfFile', combinedPdfFile);
            statusText.ForegroundColor = colors.success;
            statusText.String = sprintf( ...
                'Completed "%s": %.3f to %.3f s. Saved %d FIG files and PDF in %.1f s.\n%s', ...
                label, startTime, endTime, numel(savedFiles), toc(analysisClock), outputDirectory);
            setappdata(figureHandle, 'IntervalAnalysisProgress', struct( ...
                'stage', "complete", 'completed', 1, 'total', 1, ...
                'label', string(outputDirectory), 'elapsedSeconds', toc(analysisClock)));
            if options.PlotVisibility == "on" && ...
                    isgraphics(intervalFigures.position, 'figure')
                figure(intervalFigures.position);
            end

        catch exception

            if isgraphics(figureHandle, 'figure')
                statusText.ForegroundColor = colors.error;
                statusText.String = sprintf('Interval analysis failed: %s', exception.message);
                setappdata(figureHandle, 'LatestIntervalError', struct( ...
                    'identifier', exception.identifier, 'message', exception.message));
                setappdata(figureHandle, 'IntervalAnalysisProgress', struct( ...
                    'stage', "failed", 'completed', 0, 'total', 1, ...
                    'label', string(exception.message), 'elapsedSeconds', toc(analysisClock)));
                if visibility == "on"
                    figure(figureHandle);
                end
            end
            fprintf(2, 'Interval analysis failed: %s\n', exception.message);

        end
        clear cleanupAnalysis;

    end

    function showAnalysisProgress(stage, completed, total, label)
        if ~isgraphics(figureHandle, 'figure')
            return;
        end
        switch stage
            case "metrics"
                action = 'Calculating metrics';
            case "plots"
                action = 'Creating plots';
            case "fig"
                action = 'Saving FIG files';
            case "pdf"
                action = 'Saving PDF pages';
            case "finish"
                action = 'Finishing output';
            otherwise
                action = char(stage);
        end
        mode = 'Plot windows';
        if options.PlotVisibility == "off"
            mode = 'File-only mode';
        end
        elapsed = toc(analysisClock);
        setappdata(figureHandle, 'IntervalAnalysisProgress', struct( ...
            'stage', string(stage), 'completed', completed, 'total', total, ...
            'label', string(label), 'elapsedSeconds', elapsed));
        analyzeButton.String = sprintf('%s %d/%d', action, completed, total);
        figureHandle.Name = sprintf('FLIP Interval Re-analysis | %s %d/%d', ...
            action, completed, total);
        statusText.ForegroundColor = colors.text;
        statusText.String = sprintf('%s: %s %d/%d | Elapsed %.1f s\n%s', ...
            mode, action, completed, total, elapsed, label);
        drawnow limitrate nocallbacks;
    end


    function selectIntervalRows(~, event)

        if isAnalysisRunning()
            return;
        end
        if isempty(event.Indices)

            selectedRows = zeros(0, 1);
            return;

        end

        selectedRows = unique(event.Indices(:, 1));

        if isscalar(selectedRows)

            selected = intervals(selectedRows, :);
            labelEdit.String = char(selected.Label);
            setPickingBoundary("");
            setBoundaryTime(startEdit, selected.StartTime);
            setBoundaryTime(endEdit, selected.EndTime);
            updateSelectionMarkers();

        end

    end


    function splitSavedInterval(~, ~)

        if isAnalysisRunning()
            return;
        end
        if numel(selectedRows) ~= 1

            showStatus('Select one saved interval to split.', true);
            return;

        end

        selected = intervals(selectedRows, :);
        defaultTime = (selected.StartTime + selected.EndTime) / 2;
        answer = inputdlg( ...
            'Split time from log start (s):', ...
            'Split flight interval', 1, {sprintf('%.3f', defaultTime)});

        if isempty(answer)

            return;

        end

        try

            intervals = splitFlightIntervalDefinition( ...
                intervals, selectedRows, str2double(answer{1}));
            selectedRows = zeros(0, 1);
            refreshIntervalTable();
            showStatus('The selected interval was split.', false);

        catch exception

            showStatus(exception.message, true);

        end

    end


    function mergeSavedIntervals(~, ~)

        if isAnalysisRunning()
            return;
        end
        try

            intervals = mergeFlightIntervalDefinitions( ...
                intervals, selectedRows, labelEdit.String);
            selectedRows = zeros(0, 1);
            refreshIntervalTable();
            showStatus('The selected intervals were merged.', false);

        catch exception

            showStatus(exception.message, true);

        end

    end


    function deleteSavedIntervals(~, ~)

        if isAnalysisRunning()
            return;
        end
        if isempty(selectedRows)

            showStatus('Select one or more saved intervals to delete.', true);
            return;

        end

        intervals(selectedRows, :) = [];
        selectedRows = zeros(0, 1);
        refreshIntervalTable();
        showStatus('The selected interval definitions were deleted.', false);

    end


    function refreshIntervalTable()

        intervalTable.Data = intervalTableData(intervals);
        setappdata(figureHandle, 'IntervalDefinitions', intervals);

    end


    function busy = isAnalysisRunning()
        busy = isgraphics(figureHandle, 'figure') && ...
            isappdata(figureHandle, 'IntervalAnalysisBusy') && ...
            getappdata(figureHandle, 'IntervalAnalysisBusy');
    end

    function showStatus(message, isError)

        statusText.String = message;

        if isError

            statusText.ForegroundColor = colors.error;

        else

            statusText.ForegroundColor = colors.success;

        end

    end

end


function restoreIntervalAnalysisControls(figureHandle, controls, analyzeButton, intervalTable)
    if ~isgraphics(figureHandle, 'figure')
        return;
    end
    setappdata(figureHandle, 'IntervalAnalysisBusy', false);
    set(controls(isgraphics(controls)), 'Enable', 'on');
    if isgraphics(intervalTable)
        intervalTable.Enable = 'on';
    end
    analyzeButton.String = 'Add & analyze';
    figureHandle.Pointer = 'arrow';
    figureHandle.Name = 'FLIP Interval Re-analysis';
    drawnow limitrate nocallbacks;
end


function setBoundaryTime(control, time)
    control.String = sprintf('%.6f', time);
    control.UserData = time;
end


function time = readBoundaryTime(control)
    time = str2double(control.String);
    exactTime = control.UserData;
    % Use the exact selected timestamp while its rounded display text is unchanged.
    if isnumeric(exactTime) && isscalar(exactTime) && isfinite(exactTime) && ...
            strcmp(control.String, sprintf('%.6f', exactTime))
        time = exactTime;
    end
end


function colors = intervalWindowColors()
    colors = struct('window', [0.96 0.97 0.99], ...
        'text', [0.08 0.12 0.18], 'border', [0.70 0.75 0.82], ...
        'primary', [0.10 0.28 0.50], 'button', [0.91 0.94 0.98], ...
        'success', [0.04 0.34 0.16], 'error', [0.70 0.06 0.10]);
end


function styleIntervalWindow(figureHandle, colors)
    fontName = 'Segoe UI';
    controls = findall(figureHandle, 'Type', 'uicontrol');
    for control = reshape(controls, 1, [])
        set(control, 'FontName', fontName, 'FontUnits', 'points', ...
            'FontSize', 12, 'ForegroundColor', colors.text);
        if ismember(control.Style, {'pushbutton', 'togglebutton'})
            set(control, 'BackgroundColor', colors.button, 'FontWeight', 'bold');
        elseif strcmp(control.Style, 'edit')
            control.BackgroundColor = [1 1 1];
        elseif isprop(control.Parent, 'BackgroundColor')
            control.BackgroundColor = control.Parent.BackgroundColor;
        else
            control.BackgroundColor = figureHandle.Color;
        end
    end
    primary = findobj(figureHandle, 'Tag', 'analyzeIntervalButton');
    set(primary, 'BackgroundColor', colors.primary, 'ForegroundColor', [1 1 1]);
    tables = findall(figureHandle, 'Type', 'uitable');
    set(tables, 'FontName', fontName, 'FontSize', 12, ...
        'ForegroundColor', colors.text, ...
        'BackgroundColor', [1 1 1; 0.94 0.96 0.99]);
    panels = findall(figureHandle, 'Type', 'uipanel');
    set(panels, 'FontName', fontName, 'FontSize', 12, ...
        'FontWeight', 'bold', 'ForegroundColor', colors.text);
    tabs = [findall(figureHandle, 'Type', 'uitabgroup'); ...
        findall(figureHandle, 'Type', 'uitab')];
    for tab = reshape(tabs, 1, [])
        if isprop(tab, 'FontSize')
            tab.FontSize = 12;
        end
        if isprop(tab, 'ForegroundColor')
            tab.ForegroundColor = colors.text;
        end
    end
    ax = findobj(figureHandle, 'Tag', 'intervalOverviewAxes');
    set(ax, 'Color', [1 1 1], 'XColor', colors.text, 'YColor', colors.text, ...
        'FontName', fontName, 'FontSize', 12, 'LineWidth', 1, ...
        'GridColor', [0.65 0.70 0.78], 'GridAlpha', 0.35);
    set(findall(ax, 'Type', 'text'), 'FontName', fontName, 'Color', colors.text);
    set(ax.Title, 'FontSize', 14, 'FontWeight', 'bold');
    set([ax.XLabel, ax.YLabel], 'FontSize', 12);
    set(findall(figureHandle, 'Type', 'legend'), ...
        'FontName', fontName, 'FontSize', 11, 'TextColor', colors.text, ...
        'Color', [1 1 1], 'EdgeColor', colors.border);
end


function createStateTable(parent, flightData)

    data = cell(0, 4);

    if isfield(flightData, 'stateTimeline') && ...
            istable(flightData.stateTimeline) && ...
            ~isempty(flightData.stateTimeline)

        timeline = flightData.stateTimeline;
        data = cell(height(timeline), 4);

        for rowIndex = 1:height(timeline)

            data{rowIndex, 1} = sprintf('%.3f', timeline.Time(rowIndex));
            data{rowIndex, 2} = char(timeline.Category(rowIndex));
            data{rowIndex, 3} = char(timeline.State(rowIndex));

            if timeline.IsAlert(rowIndex)

                data{rowIndex, 4} = 'Alert';

            else

                data{rowIndex, 4} = '';

            end

        end

    end

    uitable(parent, ...
        'Data', data, ...
        'ColumnName', {'Time (s)', 'Boundary', 'State', 'Flag'}, ...
        'ColumnWidth', {80, 145, 155, 50}, ...
        'RowName', [], ...
        'Units', 'normalized', ...
        'Position', [0.01, 0.01, 0.98, 0.98], ...
        'Tag', 'stateBoundaryTable');

end


function [tableHandle, buttons] = createIntervalTable(parent)

    tableHandle = uitable(parent, ...
        'Data', cell(0, 4), ...
        'ColumnName', {'Label', 'Start (s)', 'End (s)', 'Duration (s)'}, ...
        'ColumnWidth', {170, 85, 85, 100}, ...
        'RowName', [], ...
        'Units', 'normalized', ...
        'Position', [0.02, 0.20, 0.96, 0.78], ...
        'Tag', 'savedIntervalTable');
    buttonNames = {'Analyze', 'Split', 'Merge', 'Delete'};
    buttonFields = {'analyze', 'split', 'merge', 'delete'};
    buttons = struct();

    for buttonIndex = 1:numel(buttonNames)

        buttons.(buttonFields{buttonIndex}) = uicontrol(parent, ...
            'Style', 'pushbutton', ...
            'String', buttonNames{buttonIndex}, ...
            'Units', 'normalized', ...
            'Position', [0.02 + 0.245 * (buttonIndex - 1), ...
            0.05, 0.225, 0.10], ...
            'Tag', [buttonFields{buttonIndex}, 'SavedInterval']);

    end

end


function intervals = emptyIntervalTable()

    intervals = table(strings(0, 1), zeros(0, 1), zeros(0, 1), ...
        zeros(0, 1), 'VariableNames', ...
        {'Label', 'StartTime', 'EndTime', 'Duration'});

end


function data = intervalTableData(intervals)

    data = cell(height(intervals), 4);

    for rowIndex = 1:height(intervals)

        data{rowIndex, 1} = char(intervals.Label(rowIndex));
        data{rowIndex, 2} = intervals.StartTime(rowIndex);
        data{rowIndex, 3} = intervals.EndTime(rowIndex);
        data{rowIndex, 4} = intervals.Duration(rowIndex);

    end

end


function drawStateBoundaries(axesHandle, flightData)

    if ~isfield(flightData, 'stateTimeline') || ...
            ~istable(flightData.stateTimeline) || ...
            isempty(flightData.stateTimeline)

        return;

    end

    categories = ["Arming", "Landing", ...
        "Failsafe", "Failure detector"];
    timeline = flightData.stateTimeline;
    timeline = timeline(ismember(timeline.Category, categories), :);
    hold(axesHandle, 'on');

    for rowIndex = 1:height(timeline)

        if timeline.IsAlert(rowIndex)

            color = [0.85, 0.15, 0.15];
            lineStyle = '-';

        else

            color = [0.50, 0.50, 0.50];
            lineStyle = ':';

        end

        xline(axesHandle, timeline.Time(rowIndex), lineStyle, ...
            'Color', color, ...
            'LineWidth', 1.1, ...
            'HandleVisibility', 'off');

    end

end


function [startTime, endTime] = trajectoryTimeRange(flightData)

    if ~isstruct(flightData) || ~isfield(flightData, 'position') || ...
            ~isfield(flightData.position, 'time')

        error('FLIP:InvalidFlightData', ...
            'Preprocessed FLIP flight data is required.');

    end

    finiteTime = flightData.position.time( ...
        isfinite(flightData.position.time));

    if numel(finiteTime) < 2

        error('FLIP:NoValidTrajectory', ...
            'At least two finite local-position timestamps are required.');

    end

    startTime = min(finiteTime);
    endTime = max(finiteTime);

end


function plotOverview(axesHandle, flightData)

    time = flightData.position.time(:);
    up = -flightData.position.z(:);
    plot(axesHandle, time, up, ...
        'Color', [0.10, 0.35, 0.80], ...
        'LineWidth', 1.7, ...
        'DisplayName', 'Altitude from local origin');
    grid(axesHandle, 'on');
    box(axesHandle, 'on');
    xlabel(axesHandle, 'Time from log start (s)');
    ylabel(axesHandle, 'Local up (m)');
    title(axesHandle, 'Flight overview for interval selection');
    legend(axesHandle, 'Location', 'best');

end
