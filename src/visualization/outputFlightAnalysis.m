function [figureHandles, savedFiles, combinedPdfFile] = outputFlightAnalysis( ...
        flightData, analysisResult, logFile, outputDirectory, visibility, options)
% Create analysis plots, optionally display them, and then save their outputs.

    arguments
        flightData (1, 1) struct
        analysisResult (1, 1) struct
        logFile {mustBeTextScalar}
        outputDirectory {mustBeTextScalar}
        visibility (1, 1) string {mustBeMember(visibility, ["on", "off"])} = "on"
        options.ProgressFcn (1, 1) function_handle = @(varargin) []
    end

    figureHandles = showFlightAnalysis(flightData, analysisResult, visibility, ...
        ProgressFcn=options.ProgressFcn);
    cleanup = onCleanup(@() closeHiddenFigures(figureHandles, visibility, options.ProgressFcn));
    drawnow;
    if visibility == "on"
        fprintf('Flight plots are open. Saving copies...\n');
    else
        fprintf('Saving analysis results without opening plot windows...\n');
    end
    [~, savedFiles, combinedPdfFile] = saveInteractiveFlightFigures( ...
        figureHandles, logFile, outputDirectory, CreateRunDirectory=false, ...
        ProgressFcn=options.ProgressFcn);
    fprintf('Saved %d interactive FIG files.\nOutput directory:\n%s\n', ...
        numel(savedFiles), outputDirectory);
    clear cleanup;
end

function closeHiddenFigures(figureHandles, visibility, progressFcn)
    if visibility == "off"
        figures = struct2cell(figureHandles);
        for index = 1:numel(figures)
            if isgraphics(figures{index}, 'figure')
                progressFcn("finish", index - 1, numel(figures), "Finishing saved results");
                close(figures{index});
                progressFcn("finish", index, numel(figures), "Finishing saved results");
            end
        end
    else
        progressFcn("finish", 1, 1, "Result windows are ready");
    end
end
