function figureHandle = plotPerformanceMetrics(analysisResult, visibility)
% Display performance metrics in a tabbed MATLAB table window.

    if nargin < 2

        visibility = 'on';

    end

    figureHandle = createPerformanceMetricTableWindow( ...
        analysisResult, visibility);

end
