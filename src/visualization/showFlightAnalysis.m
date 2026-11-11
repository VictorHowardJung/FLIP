function figureHandles = showFlightAnalysis(flightData, analysisResult, visibility, options)
% Create the metric table and analysis plots for display or file output.

    arguments
        flightData (1, 1) struct
        analysisResult (1, 1) struct
        visibility (1, 1) string {mustBeMember(visibility, ["on", "off"])} = "on"
        options.ProgressFcn (1, 1) function_handle = @(varargin) []
    end

    figureHandles = struct();
    suffix = intervalTitleSuffix(analysisResult);
    options.ProgressFcn("plots", 0, 15, "Performance metrics");
    figureHandles.performanceMetrics = plotPerformanceMetrics(analysisResult, visibility);
    figureHandles.performanceMetrics.Name = [figureHandles.performanceMetrics.Name suffix];
    options.ProgressFcn("plots", 1, 15, "Performance metrics");
    drawnow;

    plots = visualizeFlightData(flightData, visibility, ...
        ProgressFcn=@(stage, completed, total, label) ...
            options.ProgressFcn(stage, completed + 1, total + 2, label));
    names = fieldnames(plots);
    for index = 1:numel(names)
        figureHandles.(names{index}) = plots.(names{index});
        figureHandles.(names{index}).Name = [plots.(names{index}).Name suffix];
    end
    options.ProgressFcn("plots", 14, 15, "Tracking errors");
    figureHandles.trackingErrors = plotTrackingErrors(analysisResult, char(visibility));
    figureHandles.trackingErrors.Name = [figureHandles.trackingErrors.Name suffix];
    options.ProgressFcn("plots", 15, 15, "Tracking errors");

    if visibility == "on"
        figure(figureHandles.performanceMetrics);
    end
    drawnow;
end

function suffix = intervalTitleSuffix(analysisResult)
    suffix = '';
    if isfield(analysisResult, 'metadata') && isfield(analysisResult.metadata, 'interval')
        interval = analysisResult.metadata.interval;
        suffix = sprintf(' | Interval %.3f to %.3f s', ...
            interval.requestedStartTime, interval.requestedEndTime);
    end
end
