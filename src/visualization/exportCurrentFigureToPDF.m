function outputFile = exportCurrentFigureToPDF(figureHandle, outputFile)
% Export a figure's current zoom and pan view to PDF.

    if nargin < 1 || isempty(figureHandle)
        figureHandle = gcf;
    end

    if ~isgraphics(figureHandle, 'figure')
        error('FLIP:InvalidFigureHandle', ...
            'A valid MATLAB figure is required for PDF export.');
    end

    if nargin < 2 || strlength(string(outputFile)) == 0
        outputFile = selectOutputFile(figureHandle);

        if strlength(string(outputFile)) == 0
            return;
        end
    end

    outputFile = char(outputFile);
    [outputDirectory, ~, extension] = fileparts(outputFile);

    if isempty(extension)
        outputFile = [outputFile '.pdf'];
    elseif ~strcmpi(extension, '.pdf')
        error('FLIP:InvalidPdfExtension', ...
            'The export file must use the .pdf extension.');
    end

    if ~isempty(outputDirectory) && ~isfolder(outputDirectory)
        mkdir(outputDirectory);
    end

    exportFlightFigurePage(figureHandle, outputFile);
    fprintf('Current figure view exported to:\n%s\n', outputFile);

end


function outputFile = selectOutputFile(figureHandle)

    if isappdata(figureHandle, 'FLIPDefaultPdfFile')
        suggestedFile = getappdata(figureHandle, 'FLIPDefaultPdfFile');
    else
        suggestedFile = fullfile(pwd, 'flight_plot_current_view.pdf');
    end

    [fileName, filePath] = uiputfile( ...
        {'*.pdf', 'PDF Files (*.pdf)'}, ...
        'Export Current Figure View to PDF', suggestedFile);

    if isequal(fileName, 0)
        outputFile = '';
    else
        outputFile = fullfile(filePath, fileName);
    end

end
