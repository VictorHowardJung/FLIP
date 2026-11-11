function exportOptions = buildFigurePdfExportOptions(figureHandle)
% Select vector or raster PDF output for the figure's graphics.

    if ~isgraphics(figureHandle, 'figure')
        error('FLIP:InvalidFigureHandle', ...
            'A valid MATLAB figure is required to select PDF options.');
    end

    hasThreeDimensionalTrajectory = ~isempty(findall(figureHandle, ...
        'Type', 'axes', 'Tag', 'trajectory3D'));

    if hasThreeDimensionalTrajectory
        % Raster output includes the trajectory's transparent 3D surfaces.
        exportOptions = { ...
            'ContentType', 'image', ...
            'Resolution', 300, ...
            'BackgroundColor', 'white'};
    else
        exportOptions = { ...
            'ContentType', 'vector', ...
            'BackgroundColor', 'white'};
    end

end
