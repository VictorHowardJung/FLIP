function views = createSynchronizedReplayViews(parent, replay)
% Display position-based trajectories in a fixed operator frame with Unreal.

    resolveTime = createReplayTimeResolver(replay);
    layout = uigridlayout(parent, [1 2]);
    layout.ColumnWidth = {'1x', '3x'};
    layout.Padding = [0 0 0 0];
    leftPanel = uipanel(layout, 'Title', 'Fixed operator view');
    rightPanel = uipanel(layout, 'Title', 'FLIP 3D reconstruction');
    leftPanel.Layout.Row = 1;
    leftPanel.Layout.Column = 1;
    rightPanel.Layout.Row = 1;
    rightPanel.Layout.Column = 2;
    leftLayout = uigridlayout(leftPanel, [3 1]);
    leftLayout.RowHeight = {'1x', '1x', 24};
    leftLayout.Padding = [0 0 0 0];
    leftLayout.RowSpacing = 4;
    rightLayout = uigridlayout(rightPanel, [2 1]);
    rightLayout.RowHeight = {'1x', 24};
    rightLayout.Padding = [0 0 0 0];
    rightLayout.RowSpacing = 0;
    rightAxes = uiaxes(rightLayout, 'Tag', 'Replay3DImageAxes');
    rightAxes.Layout.Row = 1;
    rightAxes.Layout.Column = 1;
    sceneImage = image(rightAxes, zeros(1080, 1920, 3, 'uint8'), ...
        'Tag', 'Replay3DImage');
    if isprop(sceneImage, 'Interpolation')
        sceneImage.Interpolation = 'bilinear';
    end
    if isprop(sceneImage, 'MaxRenderedResolution')
        sceneImage.MaxRenderedResolution = 'none';
    end
    axis(rightAxes, 'image');
    axis(rightAxes, 'off');
    rightAxes.PositionConstraint = 'outerposition';
    rightAxes.Interactions = [];
    rightClock = uilabel(rightLayout, 'Text', 'Waiting for 3D frame', ...
        'Tag', 'Replay3DTime');
    rightClock.Layout.Row = 2;
    leftClock = uilabel(leftLayout, 'Text', 'Waiting for 3D frame', ...
        'Tag', 'Replay2DTime');
    leftClock.Layout.Row = 3;
    lastImageSize = [1080 1920];

    coordinates = replay.positionFRUData;
    coordinates(~replay.validPoseData, :) = NaN;
    [sideAxes, sideTrail, sideMarker] = createTrajectoryAxes( ...
        leftLayout, 1, coordinates(:, [2 3]), 'Operator view', ...
        'Right from start (m)', 'Up from start (m)', 'ReplaySide');
    [topAxes, topTrail, topMarker] = createTrajectoryAxes( ...
        leftLayout, 2, coordinates(:, [2 1]), 'Top view', ...
        'Right from start (m)', 'Forward from start (m)', 'Replay2D');
    playerFigure = ancestor(parent, 'figure');
    views = struct('Update', @updateFrame, 'Axes2D', topAxes, ...
        'AxesSide', sideAxes, 'AxesTop', topAxes, 'Axes3D', rightAxes, ...
        'Marker2D', topMarker, 'MarkerSide', sideMarker, ...
        'MarkerTop', topMarker, 'Image3D', sceneImage);

    function selection = updateFrame(rgb, sourceTime)
        selection = resolveTime(sourceTime);
        index = selection.frameIndex;
        sideTrail.XData = coordinates(1:index, 2);
        sideTrail.YData = coordinates(1:index, 3);
        sideMarker.XData = coordinates(index, 2);
        sideMarker.YData = coordinates(index, 3);
        topTrail.XData = coordinates(1:index, 2);
        topTrail.YData = coordinates(1:index, 1);
        topMarker.XData = coordinates(index, 2);
        topMarker.YData = coordinates(index, 1);
        imageSize = [size(rgb, 1), size(rgb, 2)];
        if ~isequal(lastImageSize, imageSize)
            sceneImage.XData = [1 imageSize(2)];
            sceneImage.YData = [1 imageSize(1)];
            xlim(rightAxes, [0.5 imageSize(2) + 0.5]);
            ylim(rightAxes, [0.5 imageSize(1) + 0.5]);
            lastImageSize = imageSize;
        end
        sceneImage.CData = rgb;
        clockText = sprintf('Log time: %.6f s | frame %d | %s', ...
            selection.time, index, selection.poseStatus);
        leftClock.Text = clockText;
        rightClock.Text = clockText;
        frame = struct('time', selection.time, 'frameIndex', index, ...
            'validPose', selection.validPose, 'sourceTime', sourceTime, ...
            'imageSize', imageSize);
        setappdata(playerFigure, 'FLIPDisplayedFrame', frame);
    end
end

function [axesHandle, trail, marker] = createTrajectoryAxes( ...
        parent, row, coordinates, titleText, horizontalLabel, verticalLabel, tagPrefix)
    axesHandle = uiaxes(parent, 'Tag', [tagPrefix 'Axes']);
    axesHandle.Layout.Row = row;
    axesHandle.Layout.Column = 1;
    plot(axesHandle, coordinates(:, 1), coordinates(:, 2), ...
        'Color', [0.7 0.75 0.8], 'LineWidth', 1);
    hold(axesHandle, 'on');
    trail = plot(axesHandle, NaN, NaN, 'Color', [0.05 0.4 0.8], ...
        'LineWidth', 2, 'Tag', [tagPrefix 'Trail']);
    marker = plot(axesHandle, NaN, NaN, 'o', 'MarkerSize', 9, ...
        'MarkerFaceColor', [0.95 0.3 0.1], 'Tag', [tagPrefix 'Marker']);
    title(axesHandle, titleText);
    xlabel(axesHandle, horizontalLabel);
    ylabel(axesHandle, verticalLabel);
    grid(axesHandle, 'on');
    axis(axesHandle, 'equal');
    axesHandle.XDir = 'normal';
    axesHandle.YDir = 'normal';
    axesHandle.XTickLabelRotation = 0;
    axesHandle.YTickLabelRotation = 0;
    axesHandle.Interactions = [];
    axesHandle.Toolbar.Visible = 'off';
    axesHandle.PositionConstraint = 'outerposition';
    xlim(axesHandle, xlim(axesHandle));
    ylim(axesHandle, ylim(axesHandle));
end
