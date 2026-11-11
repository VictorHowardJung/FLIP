function [outputFile, pageCount] = exportFlightFiguresToPDF( ...
        figureSource, outputFile, options)
% Export FLIP plots into one PDF with one figure per page.

    arguments
        figureSource = []
        outputFile {mustBeTextScalar} = ""
        options.ProgressFcn (1, 1) function_handle = @(varargin) []
    end

    if nargin < 1 || isempty(figureSource)
        figureSource = gcf;
    end

    [figureHandles, temporaryFigures, suggestedFile] = ...
        resolveFigureCollection(figureSource);
    cleanup = onCleanup(@() closeTemporaryFigures(temporaryFigures));

    if isempty(figureHandles)
        error('FLIP:NoFiguresForCombinedPdf', ...
            'No valid FLIP figures are available for combined PDF export.');
    end

    if nargin < 2 || strlength(string(outputFile)) == 0
        outputFile = selectCombinedOutputFile(suggestedFile);

        if strlength(string(outputFile)) == 0
            pageCount = 0;
            return;
        end
    end

    outputFile = normalizePdfFile(outputFile);
    outputDirectory = fileparts(outputFile);

    if ~isempty(outputDirectory) && ~isfolder(outputDirectory)
        mkdir(outputDirectory);
    end

    if isfile(outputFile)
        delete(outputFile);
    end

    pageCount = 0;

    try
        for index = 1:numel(figureHandles)
            figureHandle = figureHandles(index);
            options.ProgressFcn("pdf", index - 1, numel(figureHandles), figureHandle.Name);
            exportFlightFigurePage(figureHandle, outputFile, index > 1);
            pageCount = pageCount + 1;
            options.ProgressFcn("pdf", index, numel(figureHandles), figureHandle.Name);
        end
    catch exception
        if isfile(outputFile)
            delete(outputFile);
        end
        rethrow(exception);
    end

    fprintf('Combined flight-plot PDF exported (%d pages):\n%s\n', ...
        pageCount, outputFile);
    clear cleanup;

end


function [figureHandles, temporaryFigures, suggestedFile] = ...
        resolveFigureCollection(figureSource)

    temporaryFigures = gobjects(0, 1);
    suggestedFile = '';

    if isstruct(figureSource)
        figureHandles = orderedStructFigures(figureSource);

        if ~isempty(figureHandles) && ...
                isappdata(figureHandles(1), 'FLIPCombinedPdfFile')
            suggestedFile = getappdata( ...
                figureHandles(1), 'FLIPCombinedPdfFile');
        end
        return;
    end

    figureSource = figureSource(:);
    figureSource = figureSource(isgraphics(figureSource, 'figure'));

    if isempty(figureSource)
        figureHandles = gobjects(0, 1);
        return;
    end

    referenceFigure = figureSource(1);

    if isappdata(referenceFigure, 'FLIPCombinedPdfFile')
        suggestedFile = getappdata(referenceFigure, 'FLIPCombinedPdfFile');
    end

    if ~isappdata(referenceFigure, 'FLIPFigureOutputDirectory')
        figureHandles = figureSource;
        return;
    end

    outputDirectory = getappdata( ...
        referenceFigure, 'FLIPFigureOutputDirectory');
    [figureHandles, temporaryFigures] = ...
        collectCurrentFigures(outputDirectory);

end


function figureHandles = orderedStructFigures(figureStruct)

    fieldOrder = { ...
        'position', 'velocity', 'attitude', 'rates', ...
        'motors', 'battery', 'vibration', 'estimator', 'gps', ...
        'controlDemand', 'pilotResponse', 'systemHealth', ...
        'performanceMetrics', 'trackingErrors', 'trajectory'};
    figureHandles = gobjects(0, 1);

    for index = 1:numel(fieldOrder)
        fieldName = fieldOrder{index};

        if isfield(figureStruct, fieldName) && ...
                isgraphics(figureStruct.(fieldName), 'figure')
            figureHandles(end + 1, 1) = ...
                figureStruct.(fieldName); %#ok<AGROW>
        end
    end

    remainingFields = setdiff(fieldnames(figureStruct), ...
        fieldOrder, 'stable');

    for index = 1:numel(remainingFields)
        figureHandle = figureStruct.(remainingFields{index});

        if isgraphics(figureHandle, 'figure')
            figureHandles(end + 1, 1) = figureHandle; %#ok<AGROW>
        end
    end

end


function [figureHandles, temporaryFigures] = ...
        collectCurrentFigures(outputDirectory)

    fileStems = { ...
        'position_tracking', ...
        'velocity_tracking', ...
        'attitude_tracking', ...
        'angular_rate_tracking', ...
        'motor_command_output', ...
        'battery_power_health', ...
        'imu_vibration_diagnostics', ...
        'estimator_diagnostics', ...
        'gps_diagnostics', ...
        'control_demand', ...
        'pilot_input_response', ...
        'system_link_health', ...
        'performance_metrics', ...
        'tracking_errors', ...
        'flight_trajectory'};
    figureHandles = gobjects(0, 1);
    temporaryFigures = gobjects(0, 1);
    openFigures = findall(groot, 'Type', 'figure');

    for index = 1:numel(fileStems)
        fileStem = fileStems{index};
        matchingFigure = findMatchingOpenFigure( ...
            openFigures, outputDirectory, fileStem);

        if isempty(matchingFigure)
            figFile = fullfile(outputDirectory, [fileStem '.fig']);

            if ~isfile(figFile)
                continue;
            end

            matchingFigure = openfig(figFile, 'invisible');
            temporaryFigures(end + 1, 1) = matchingFigure; %#ok<AGROW>
        end

        figureHandles(end + 1, 1) = matchingFigure(1); %#ok<AGROW>
    end

end


function figureHandle = findMatchingOpenFigure( ...
        openFigures, outputDirectory, fileStem)

    figureHandle = gobjects(0, 1);

    for index = 1:numel(openFigures)
        candidate = openFigures(index);

        if ~isappdata(candidate, 'FLIPFigureOutputDirectory') || ...
                ~isappdata(candidate, 'FLIPFigureFileStem')
            continue;
        end

        candidateDirectory = getappdata( ...
            candidate, 'FLIPFigureOutputDirectory');
        candidateStem = getappdata(candidate, 'FLIPFigureFileStem');

        if strcmp(candidateDirectory, outputDirectory) && ...
                strcmp(candidateStem, fileStem)
            figureHandle = candidate;
            return;
        end
    end

end


function outputFile = selectCombinedOutputFile(suggestedFile)

    if strlength(string(suggestedFile)) == 0
        suggestedFile = fullfile(pwd, 'flight_plots_current_view.pdf');
    end

    [fileName, filePath] = uiputfile( ...
        {'*.pdf', 'PDF Files (*.pdf)'}, ...
        'Export All FLIP Plots to One PDF', suggestedFile);

    if isequal(fileName, 0)
        outputFile = '';
    else
        outputFile = fullfile(filePath, fileName);
    end

end


function outputFile = normalizePdfFile(outputFile)

    outputFile = char(outputFile);
    [~, ~, extension] = fileparts(outputFile);

    if isempty(extension)
        outputFile = [outputFile '.pdf'];
    elseif ~strcmpi(extension, '.pdf')
        error('FLIP:InvalidPdfExtension', ...
            'The export file must use the .pdf extension.');
    end

end


function closeTemporaryFigures(figureHandles)

    figureHandles = figureHandles(isgraphics(figureHandles, 'figure'));

    if ~isempty(figureHandles)
        close(figureHandles);
    end

end
