function [intervalData, intervalResult] = reanalyzeFlightInterval( ...
        flightData, startTime, endTime, label, options)
% Evaluate tracking performance over a selected flight interval.

    arguments
        flightData (1, 1) struct
        startTime (1, 1) double
        endTime (1, 1) double
        label = 'Selected interval'
        options.SettlingThreshold (1, 1) double {mustBePositive, mustBeFinite} = 0.02
        options.ResponseMode (1, 1) string {mustBeMember(options.ResponseMode, ["selected", "detected"])} = "selected"
    end

    intervalData = extractFlightInterval( ...
        flightData, startTime, endTime, label);
    intervalResult = evaluateTrackingPerformance(intervalData);
    intervalResult.controlResponse = evaluateIntervalControlPerformance( ...
        flightData, startTime, endTime, SettlingThreshold=options.SettlingThreshold, ...
        ResponseMode=options.ResponseMode, TrackingResult=intervalResult);

    intervalResult.metadata.analysisScope = 'interval';
    intervalResult.metadata.interval = ...
        intervalData.metadata.analysisInterval;

end
