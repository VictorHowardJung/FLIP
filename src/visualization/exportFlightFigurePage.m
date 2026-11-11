function exportFlightFigurePage(figureHandle, outputFile, appendPage)
% Export one PDF page, including the selected UI table view.

    if nargin < 3
        appendPage = false;
    end

    source = figureHandle;
    if ~isempty(findall(figureHandle, 'Type', 'uitable'))
        % Capture the selected UI tab as an image for PDF page composition.
        temporaryImage = [tempname '.png'];
        cleanupImage = onCleanup(@() deleteTemporaryImage(temporaryImage));
        exportapp(figureHandle, temporaryImage);
        rgb = imread(temporaryImage);
        temporaryFigure = figure('Visible', 'off', 'HandleVisibility', 'off', ...
            'Color', 'white', 'Position', [1 1 size(rgb, 2) size(rgb, 1)]);
        cleanupFigure = onCleanup(@() deleteTemporaryFigure(temporaryFigure));
        source = axes(temporaryFigure, 'Units', 'normalized', ...
            'Position', [0 0 1 1]);
        image(source, rgb);
        axis(source, 'image');
        axis(source, 'off');
        exportOptions = {'ContentType', 'image', 'Resolution', 300, ...
            'BackgroundColor', 'white'};
    else
        exportOptions = buildFigurePdfExportOptions(figureHandle);
    end

    if appendPage
        exportOptions = [exportOptions, {'Append', true}];
    end
    drawnow;
    exportgraphics(source, outputFile, exportOptions{:});
    clear cleanupFigure cleanupImage;
end

function deleteTemporaryFigure(figureHandle)
    if isgraphics(figureHandle)
        delete(figureHandle);
    end
end

function deleteTemporaryImage(path)
    if isfile(path)
        delete(path);
    end
end
