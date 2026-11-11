function zoomFlightTimeAxis(figureHandle, eventData, axesHandle)
% Zoom the time axis around the mouse pointer using the scroll wheel.

    if nargin < 3
        axesHandle = gobjects(0, 1);
    end

    axesHandle = selectInteractiveAxes(axesHandle);

    if isempty(axesHandle) && isscalar(figureHandle) && ...
            isgraphics(figureHandle, 'figure')
        hitObject = hittest(figureHandle);
        axesHandle = selectInteractiveAxes(ancestor(hitObject, 'axes'));
    end

    if isempty(axesHandle) || ...
            ~isappdata(axesHandle, 'FLIPFullTimeLimits')
        return;
    end

    scrollCount = extractScrollCount(eventData);

    if ~isscalar(scrollCount) || ~isfinite(scrollCount) || scrollCount == 0
        return;
    end

    fullLimits = getappdata(axesHandle, 'FLIPFullTimeLimits');
    currentLimits = xlim(axesHandle);
    fullWidth = diff(fullLimits);
    currentWidth = diff(currentLimits);

    if any(~isfinite([fullLimits currentLimits])) || ...
            fullWidth <= 0 || currentWidth <= 0
        return;
    end

    zoomFactor = 1.25 ^ double(scrollCount);
    minimumWidth = min(fullWidth, max(0.01, fullWidth / 10000));
    newWidth = min(fullWidth, max(minimumWidth, ...
        currentWidth * zoomFactor));
    anchorTime = pointerTime(axesHandle, currentLimits);
    anchorFraction = (anchorTime - currentLimits(1)) / currentWidth;
    newLimits = [ ...
        anchorTime - anchorFraction * newWidth, ...
        anchorTime + (1 - anchorFraction) * newWidth];
    newLimits = constrainToFullRange(newLimits, fullLimits);
    xlim(axesHandle, newLimits);

end


function axesHandle = selectInteractiveAxes(candidates)

    axesHandle = gobjects(0, 1);

    if isempty(candidates)
        return;
    end

    candidates = candidates(:);
    candidates = candidates(isgraphics(candidates, 'axes'));

    for index = 1:numel(candidates)
        if isappdata(candidates(index), 'FLIPFullTimeLimits')
            axesHandle = candidates(index);
            return;
        end
    end

end


function scrollCount = extractScrollCount(eventData)

    scrollCount = NaN;

    if isstruct(eventData) && isfield(eventData, 'VerticalScrollCount')
        scrollCount = eventData.VerticalScrollCount;
    elseif isobject(eventData) && isprop(eventData, 'VerticalScrollCount')
        scrollCount = eventData.VerticalScrollCount;
    end

end


function anchorTime = pointerTime(axesHandle, currentLimits)

    currentPoint = axesHandle.CurrentPoint;
    anchorTime = currentPoint(1, 1);

    if ~isfinite(anchorTime) || anchorTime < currentLimits(1) || ...
            anchorTime > currentLimits(2)
        anchorTime = mean(currentLimits);
    end

end


function limits = constrainToFullRange(limits, fullLimits)

    if limits(1) < fullLimits(1)
        limits = limits + (fullLimits(1) - limits(1));
    end

    if limits(2) > fullLimits(2)
        limits = limits - (limits(2) - fullLimits(2));
    end

    limits(1) = max(limits(1), fullLimits(1));
    limits(2) = min(limits(2), fullLimits(2));

end
