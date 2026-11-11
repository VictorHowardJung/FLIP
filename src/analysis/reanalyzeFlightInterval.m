function [intervalData, intervalResult] = reanalyzeFlightInterval( ...
        flightData, startTime, endTime, label)
% Evaluate tracking performance over a selected flight interval.

    if nargin < 4

        label = 'Selected interval';

    end

    intervalData = extractFlightInterval( ...
        flightData, startTime, endTime, label);
    intervalResult = evaluateTrackingPerformance(intervalData);

    intervalResult.metadata.analysisScope = 'interval';
    intervalResult.metadata.interval = ...
        intervalData.metadata.analysisInterval;

end
