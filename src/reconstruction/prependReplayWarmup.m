function output = prependReplayWarmup(input, sampleTime, frameCount)
% Hold the first pose during Unreal initialization.
% Pre-roll uses log-relative time and supports time-first and time-last data.
    if nargin < 3
        frameCount = 2;
    end
    warmup = getsamples(input, 1);
    warmup.Time = input.Time(1) - frameCount * sampleTime;
    output = append(warmup, input);
    % Offset held-sample timestamps to select the current frame at rounding boundaries.
    tolerance = max(sampleTime * 1e-9, 64 * eps(max(abs(output.Time))));
    output.Time = output.Time - tolerance;
end
