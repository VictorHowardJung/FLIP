function [outputDirectory, savedFiles, combinedPdfFile] = ...
        saveInteractiveFlightFigures( ...
        figureHandles, logFile, outputRoot, options)
% Save FLIP figures as interactive FIG files that preserve zoom and inspection.

    arguments
        figureHandles (1, 1) struct
        logFile {mustBeTextScalar}
        outputRoot {mustBeTextScalar} = defaultFigureRoot()
        options.CreateRunDirectory (1, 1) logical = true
        options.ProgressFcn (1, 1) function_handle = @(varargin) []
    end

    outputRoot = char(outputRoot);

    if ~isfolder(outputRoot)
        mkdir(outputRoot);
    end

    [~, logName, logExtension] = fileparts(char(logFile));
    sourceLogName = [logName logExtension];
    if options.CreateRunDirectory
        session = createAnalysisOutputSession(outputRoot);
        outputDirectory = session.originalDirectory;
    else
        outputDirectory = outputRoot;
        contents = dir(outputDirectory);
        if any(~ismember({contents.name}, {'.', '..'}))
            error('FLIP:OutputDirectoryNotEmpty', ...
                'Choose an empty output directory to preserve existing results:\n%s', ...
                outputDirectory);
        end
    end

    names = fieldnames(figureHandles);
    names = names(cellfun(@(name) isgraphics(figureHandles.(name), 'figure'), names));
    savedFiles = strings(0, 1);
    combinedPdfFile = fullfile( ...
        outputDirectory, 'flight_plots_current_view.pdf');

    for index = 1:numel(names)
        figureHandle = figureHandles.(names{index});

        if ~isgraphics(figureHandle, 'figure')
            continue;
        end

        options.ProgressFcn("fig", index - 1, numel(names), figureHandle.Name);
        fileStem = figureFileStem(names{index});
        figFile = fullfile(outputDirectory, [fileStem '.fig']);
        pdfFile = fullfile(outputDirectory, [fileStem '_current_view.pdf']);
        setappdata(figureHandle, 'FLIPSourceLogName', sourceLogName);
        setappdata(figureHandle, 'FLIPFigureFileStem', fileStem);
        setappdata(figureHandle, ...
            'FLIPFigureOutputDirectory', outputDirectory);
        setappdata(figureHandle, ...
            'FLIPCombinedPdfFile', combinedPdfFile);
        attachPdfExportMenu(figureHandle, pdfFile);
        attachCombinedPdfExportMenu(figureHandle);
        saveFigureForInteractiveOpening(figureHandle, figFile);
        savedFiles(end + 1, 1) = string(figFile); %#ok<AGROW>
        options.ProgressFcn("fig", index, numel(names), figureHandle.Name);
    end

    if ~isempty(savedFiles)
        exportFlightFiguresToPDF(figureHandles, combinedPdfFile, ...
            ProgressFcn=options.ProgressFcn);
    else
        combinedPdfFile = '';
    end

    % Link displayed time axes after saving their independent FIG files.
    for index = 1:numel(names)
        figureHandle = figureHandles.(names{index});
        if ~isgraphics(figureHandle, 'figure')
            continue;
        end
        axesHandles = findall(figureHandle, 'Type', 'axes');
        timeAxes = false(size(axesHandles));
        for axesIndex = 1:numel(axesHandles)
            timeAxes(axesIndex) = isappdata(axesHandles(axesIndex), 'FLIPFullTimeLimits');
        end
        axesHandles = axesHandles(timeAxes);
        if numel(axesHandles) > 1
            key = 'FLIPTimeAxesLink';
            if isappdata(figureHandle, key)
                previousLink = getappdata(figureHandle, key);
                if isvalid(previousLink)
                    delete(previousLink);
                end
            end
            setappdata(figureHandle, key, linkprop(axesHandles, 'XLim'));
        end
    end

end


function saveFigureForInteractiveOpening(figureHandle, figFile)

    originalCreateFunction = figureHandle.CreateFcn;
    restoreCreateFunction = onCleanup(@() set( ...
        figureHandle, 'CreateFcn', originalCreateFunction));

    % Display the figure when a saved FIG is opened normally.
    figureHandle.CreateFcn = @(source, ~) set( ...
        source, 'Visible', 'on');
    savefig(figureHandle, figFile);
    clear restoreCreateFunction;

end


function outputRoot = defaultFigureRoot()

    projectRoot = fileparts(fileparts(fileparts(mfilename('fullpath'))));
    outputRoot = fullfile(projectRoot, 'results', 'figures');

end


function fileStem = figureFileStem(fieldName)

    switch fieldName
        case 'position'
            fileStem = 'position_tracking';
        case 'velocity'
            fileStem = 'velocity_tracking';
        case 'attitude'
            fileStem = 'attitude_tracking';
        case 'rates'
            fileStem = 'angular_rate_tracking';
        case 'motors'
            fileStem = 'motor_command_output';
        case 'battery'
            fileStem = 'battery_power_health';
        case 'vibration'
            fileStem = 'imu_vibration_diagnostics';
        case 'estimator'
            fileStem = 'estimator_diagnostics';
        case 'gps'
            fileStem = 'gps_diagnostics';
        case 'controlDemand'
            fileStem = 'control_demand';
        case 'pilotResponse'
            fileStem = 'pilot_input_response';
        case 'systemHealth'
            fileStem = 'system_link_health';
        case 'performanceMetrics'
            fileStem = 'performance_metrics';
        case 'trackingErrors'
            fileStem = 'tracking_errors';
        case 'trajectory'
            fileStem = 'flight_trajectory';
        otherwise
            fileStem = lower(regexprep(fieldName, ...
                '([a-z0-9])([A-Z])', '$1_$2'));
    end

end


function attachCombinedPdfExportMenu(figureHandle)

    existingMenu = findall(figureHandle, ...
        'Type', 'uimenu', 'Tag', 'flipExportAllPlotsPdf');

    if isempty(existingMenu)
        uimenu(figureHandle, ...
            'Text', 'Export All FLIP Plots to One PDF...', ...
            'Tag', 'flipExportAllPlotsPdf', ...
            'MenuSelectedFcn', @(menuHandle, ~) ...
                exportFlightFiguresToPDF( ...
                    ancestor(menuHandle, 'figure')));
    end

end


function attachPdfExportMenu(figureHandle, pdfFile)

    existingMenu = findall(figureHandle, ...
        'Type', 'uimenu', 'Tag', 'flipExportCurrentViewPdf');

    if isempty(existingMenu)
        uimenu(figureHandle, ...
            'Text', 'Export Current View to PDF...', ...
            'Separator', 'on', ...
            'Tag', 'flipExportCurrentViewPdf', ...
            'MenuSelectedFcn', @(menuHandle, ~) ...
                exportCurrentFigureToPDF( ...
                    ancestor(menuHandle, 'figure')));
    end

    setappdata(figureHandle, 'FLIPDefaultPdfFile', pdfFile);

end
