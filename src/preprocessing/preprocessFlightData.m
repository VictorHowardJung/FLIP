function flightData = preprocessFlightData(flightData)
% Normalize flight time and convert attitude before FLIP analysis.

    flightData = normalizeFlightTime(flightData);
    flightData = addEulerAngles(flightData);
    flightData = buildFlightStateTimeline(flightData);

end
