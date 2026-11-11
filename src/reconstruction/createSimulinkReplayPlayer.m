function [playerFigure, replay, modelPath] = ...
        createSimulinkReplayPlayer(flightData, options)
% Create interactive controls for Simulink/Unreal flight-log replay.

    arguments

        flightData (1, 1) struct
        options.SampleTime (1, 1) double ...
            {mustBeFinite, mustBePositive} = 1 / 60
        options.MaxInterpolationGap (1, 1) double ...
            {mustBeFinite, mustBePositive} = 0.25
        options.Scene (1, 1) string = "Airport"
        options.RebuildModel (1, 1) logical = false
        options.InitializeViewer (1, 1) logical = true
        options.SynchronizedViews (1, 1) logical = false
        options.ViewHeadingDegrees (1, 1) double {mustBeFinite} = 0
        options.GraphicsQuality (1, 1) string {mustBeMember(options.GraphicsQuality, ...
            ["low", "medium", "high", "epic", "cinematic"])} = "epic"
        options.Visible (1, 1) string ...
            {mustBeMember(options.Visible, ["on", "off"])} = "on"

    end

    validatePlayerEnvironment();
    worldOffset = getSimulinkUnrealSceneOffset(options.Scene);
    replay = prepareSimulinkUnrealReplay( ...
        flightData, ...
        SampleTime=options.SampleTime, ...
        MaxInterpolationGap=options.MaxInterpolationGap, ...
        WorldOffset=worldOffset, ViewHeadingDegrees=options.ViewHeadingDegrees);
    modelPath = defaultModelPath(options.SynchronizedViews);

    needsRebuild = options.RebuildModel || ~isfile(modelPath);
    if isfile(modelPath)
        modelInfo = dir(modelPath);
        builderInfo = dir(which('buildSimulinkUnrealReplayModel'));
        needsRebuild = needsRebuild || modelInfo.datenum < builderInfo.datenum;
    end
    if needsRebuild

        modelPath = buildSimulinkUnrealReplayModel( ...
            OutputFile=string(modelPath), Scene=options.Scene, ...
            EmbeddedCamera=options.SynchronizedViews, ...
            GraphicsQuality=options.GraphicsQuality);

    end

    [modelDirectory, modelName] = fileparts(modelPath);
    addpath(modelDirectory);
    load_system(modelPath);
    if getSimulinkBlockHandle(modelName + "/Rendering Quality") < 0
        close_system(modelName, 0);
        modelPath = buildSimulinkUnrealReplayModel( ...
            OutputFile=string(modelPath), Scene=options.Scene, ...
            EmbeddedCamera=options.SynchronizedViews, ...
            GraphicsQuality=options.GraphicsQuality);
        load_system(modelPath);
    end
    qualityScript = sprintf('configureReplayRendering(World, "%s");', ...
        options.GraphicsQuality);
    qualityBlock = modelName + "/Rendering Quality";
    if ~strcmp(get_param(qualityBlock, 'InitScriptText'), qualityScript)
        set_param(qualityBlock, 'InitScriptText', qualityScript);
    end
    replay.metadata.graphicsQuality = options.GraphicsQuality;
    sceneBlock = modelName + "/Simulation 3D Scene Configuration";
    if string(get_param(sceneBlock, 'SceneDesc')) ~= options.Scene
        set_param(sceneBlock, 'SceneDesc', char(options.Scene));
    end
    if options.SynchronizedViews
        camera = fitReplayCameraIntrinsics(replay);
        cameraBlock = modelName + "/Replay Camera";
        focalLengthText = mat2str(camera.focalLength, 17);
        if ~strcmp(get_param(cameraBlock, 'FocalLength'), focalLengthText)
            set_param(cameraBlock, 'FocalLength', focalLengthText);
        end
        replay.metadata.cameraIntrinsics = camera;
    end

    playbackRate = 1;
    resolveTime = createReplayTimeResolver(replay);
    resolveState = createReplayStateResolver(replay);
    currentSelection = resolveTime(replay.startTime);
    requestedRenderTime = replay.startTime;
    playbackStartTime = replay.startTime;
    warmupFrameCount = max(2, ceil(2 / replay.sampleTime));
    signalFields = {'translation', 'rotationYPR', 'speed', 'altitude', ...
        'validPose', 'armed', 'actorTranslation', 'actorRotation', 'actorScale'};
    frameSource = createReplayFrameSource(replay);
    simulationObject = [];
    updateTimer = [];
    renderTimer = [];
    seeking = false;
    sliderIsMoving = false;
    closingPlayer = false;
    endReached = false;
    controlsClock = tic;
    pendingPacket = struct('rgb', [], 'time', replay.startTime);
    pendingFrameAvailable = false;

    playerPosition = [120 120 920 390];
    if options.SynchronizedViews
        playerPosition = [40 60 1440 860];
    end
    playerFigure = uifigure( ...
        'Name', 'FLIP Unreal Replay Controller', ...
        'Position', playerPosition, ...
        'Visible', char(options.Visible));
    if isprop(playerFigure, 'Theme')
        playerFigure.Theme = 'light';
    end
    if options.SynchronizedViews && options.Visible == "on"
        playerFigure.WindowState = 'maximized';
    end
    playerFigure.CloseRequestFcn = @closePlayer;
    rowOffset = double(options.SynchronizedViews);
    rootLayout = uigridlayout(playerFigure, [7 + rowOffset, 1]);
    rootLayout.Padding = [12 10 12 10];
    rootLayout.RowSpacing = 7;
    rootLayout.RowHeight = {34, 58, 44, 55, 38, 30, '1x'};
    views = [];
    if options.SynchronizedViews
        playerFigure.Name = 'FLIP Synchronized 2D + 3D Replay';
        rootLayout.RowHeight = {26, '1x', 58, 34, 64, 30, 22, 30};
        rootLayout.Padding = [8 6 8 6];
        rootLayout.RowSpacing = 4;
        viewPanel = uipanel(rootLayout, 'BorderType', 'none');
        viewPanel.Layout.Row = 2;
        views = createSynchronizedReplayViews(viewPanel, replay);
        set_param(modelName + "/Replay Frame Source", ...
            'Parameters', numberText(replay.sampleTime), ...
            'UserData', struct('Read', frameSource.Read, 'Start', @startFrameSource));
        set_param(modelName + "/Synchronized Frame Sink", ...
            'UserData', @receiveRenderedFrame);
    end

    titleLabel = uilabel(rootLayout, ...
        'Text', 'FLIP Log-derived Reconstruction', ...
        'FontSize', 17, ...
        'FontWeight', 'bold', ...
        'HorizontalAlignment', 'center');
    titleLabel.Layout.Row = 1;

    simulationPanel = uipanel(rootLayout, 'Title', 'Simulation');
    simulationPanel.Layout.Row = 2 + rowOffset;
    simulationPanelLayout = uigridlayout(simulationPanel, [1 1]);
    simulationPanelLayout.Padding = [4 2 4 2];
    simulationControls = uisimcontrols( ...
        simulationPanelLayout, ...
        'Tag', 'SimulationControls', ...
        'StartText', 'Play', ...
        'PauseText', 'Pause', ...
        'ContinueText', 'Continue', ...
        'StopText', 'Stop');

    commandLayout = uigridlayout(rootLayout, [1 8]);
    commandLayout.Layout.Row = 3 + rowOffset;
    commandLayout.ColumnWidth = {88, 88, 88, 35, 75, 105, 90, '1x'};
    commandLayout.Padding = [0 0 0 0];
    commandLayout.ColumnSpacing = 7;
    uibutton(commandLayout, 'push', ...
        'Text', 'Restart', 'Tag', 'Restart', ...
        'ButtonPushedFcn', @restartReplay);
    uibutton(commandLayout, 'push', ...
        'Text', '-1 Frame', 'Tag', 'PreviousFrame', ...
        'ButtonPushedFcn', @previousFrame);
    uibutton(commandLayout, 'push', ...
        'Text', '+1 Frame', 'Tag', 'NextFrame', ...
        'ButtonPushedFcn', @nextFrame);
    uilabel(commandLayout, ...
        'Text', 'Rate', 'HorizontalAlignment', 'right');
    uidropdown(commandLayout, ...
        'Items', {'0.25x', '0.5x', '1x', '2x', '4x'}, ...
        'ItemsData', [0.25 0.5 1 2 4], ...
        'Value', 1, ...
        'Tag', 'PlaybackRate', ...
        'ValueChangedFcn', @changePlaybackRate);
    exactTimeField = uieditfield(commandLayout, 'numeric', ...
        'Limits', [replay.startTime replay.stopTime], ...
        'Value', replay.startTime, ...
        'Tag', 'ExactTime', ...
        'ValueDisplayFormat', '%.6f');
    uibutton(commandLayout, 'push', ...
        'Text', 'Seek Time', 'Tag', 'SeekTime', ...
        'ButtonPushedFcn', @seekExactTime);
    uilabel(commandLayout, ...
        'Text', 'Seek snaps to the nearest recorded replay frame.');

    timelineLayout = uigridlayout(rootLayout, [2 1]);
    timelineLayout.Layout.Row = 4 + rowOffset;
    timelineLayout.RowHeight = {19, 30};
    if options.SynchronizedViews
        timelineLayout.RowHeight = {15, '1x'};
        timelineLayout.RowSpacing = 3;
    end
    timelineLayout.Padding = [0 0 0 0];
    timelineLabel = uilabel(timelineLayout, ...
        'Text', formatTimelineLabel(currentSelection), ...
        'HorizontalAlignment', 'center');
    timelineSlider = uislider(timelineLayout, ...
        'Limits', [replay.startTime replay.stopTime], ...
        'Value', replay.startTime, ...
        'Tag', 'Timeline', ...
        'MajorTicks', linspace(replay.startTime, replay.stopTime, 5), ...
        'ValueChangingFcn', @previewTimeline, ...
        'ValueChangedFcn', @seekTimeline);

    stateLayout = uigridlayout(rootLayout, [1 3]);
    stateLayout.Layout.Row = 5 + rowOffset;
    stateLayout.ColumnWidth = {100, '1x', 100};
    stateLayout.Padding = [0 0 0 0];
    uibutton(stateLayout, 'push', ...
        'Text', 'Prev Event', ...
        'Tag', 'PreviousEvent', ...
        'ButtonPushedFcn', @previousEvent);
    stateLabel = uilabel(stateLayout, ...
        'Text', 'Flight state: preparing...', ...
        'Tag', 'CurrentFlightState', ...
        'HorizontalAlignment', 'center');
    uibutton(stateLayout, 'push', ...
        'Text', 'Next Event', ...
        'Tag', 'NextEvent', ...
        'ButtonPushedFcn', @nextEvent);

    statusLabel = uilabel(rootLayout, ...
        'Text', 'Preparing replay controller...', ...
        'Tag', 'ReplayStatus', ...
        'FontWeight', 'bold');
    statusLabel.Layout.Row = 6 + rowOffset;

    provenanceLabel = uilabel(rootLayout, ...
        'Text', [ ...
        'Estimated pose reconstructed from logged data. ' ...
        'The Airport scene is illustrative, not flight-site evidence.'], ...
        'WordWrap', 'on', ...
        'FontColor', [0.35 0.35 0.35]);
    provenanceLabel.Layout.Row = 7 + rowOffset;

    try

        rebuildSimulation(replay.startTime, options.InitializeViewer);

    catch exception

        disposeSimulation();
        releaseEmbeddedModel();
        delete(playerFigure);
        rethrow(exception);

    end

    if options.SynchronizedViews
        renderTimer = timer('ExecutionMode', 'fixedSpacing', ...
            'Period', 0.001, 'BusyMode', 'drop', ...
            'TimerFcn', @displayQueuedFrame, ...
            'StopFcn', @(~, ~) startQueuedRenderer());
    end
    updateTimer = timer( ...
        'ExecutionMode', 'fixedSpacing', ...
        'Period', 0.10, ...
        'BusyMode', 'drop', ...
        'TimerFcn', @refreshPlayer);
    start(updateTimer);
    playerFigure.UserData = struct( ...
        'Replay', replay, ...
        'ModelPath', modelPath, ...
        'Seek', @seekProgrammatically, ...
        'GetSimulation', @getSimulationObject, ...
        'Views', views);

    fprintf('\nFLIP Unreal replay controller opened.\n');
    fprintf('Time range      : %.6f to %.6f s\n', ...
        replay.startTime, replay.stopTime);
    fprintf('Frame interval  : %.6f s\n', replay.sampleTime);
    fprintf('Playback rates  : 0.25x, 0.5x, 1x, 2x, 4x\n');
    fprintf('Seek policy     : nearest frame; ties select the earlier frame\n');

    function rebuildSimulation(requestedTime, initializeViewer)

        seeking = true;
        if ~isempty(renderTimer) && isvalid(renderTimer)
            stop(renderTimer);
        end
        try
            seekSimulation(requestedTime, initializeViewer);
        catch exception
            finishSeeking();
            rethrow(exception);
        end
        finishSeeking();
    end

    function seekSimulation(requestedTime, initializeViewer)
        selection = resolveTime(requestedTime);
        playbackStartTime = selection.time;
        endReached = false;
        pendingFrameAvailable = false;
        statusLabel.Text = sprintf( ...
            'Seeking to %.6f s (frame %d)...', ...
            selection.time, selection.frameIndex);
        drawnow;
        if options.SynchronizedViews && ...
                any(simulationStatus() == ["initialized", "paused", "running"])
            if simulationStatus() == "running"
                pause(simulationObject);
            end
            requestedRenderTime = selection.time;
            frameSource.Seek(selection.time, 6);
            step(simulationObject, 'NumberOfSteps', 7);
            renderPendingFrame(true);
            updateControls(currentSelection);
            return;
        end
        disposeSimulation();
        if options.SynchronizedViews
            frameSource.Seek(selection.time, warmupFrameCount);
        end
        simulationObject = createSimulationObject(selection);
        simulationControls.Simulation = simulationObject;
        currentSelection = selection;
        requestedRenderTime = selection.time;

        if initializeViewer

            initialize(simulationObject);
            if options.SynchronizedViews
                % Hidden pre-roll prepares actors and streams scene textures.
                step(simulationObject, 'NumberOfSteps', warmupFrameCount + 1);
                renderPendingFrame(true);
                updateControls(currentSelection);
            end

        end

        if ~options.SynchronizedViews || ~initializeViewer
            updateControls(selection);
        end

    end

    function finishSeeking()
        seeking = false;
        startQueuedRenderer();
    end

    function simObject = createSimulationObject(selection)

        simulationStart = selection.time;
        simulationStop = replay.stopTime;
        if options.SynchronizedViews
            simulationStart = selection.time - warmupFrameCount * replay.sampleTime;
            simulationStop = Inf;
        end
        simObject = simulation(modelName);
        simObject = setModelParameter(simObject, ...
            'StartTime', numberText(simulationStart), ...
            'StopTime', numberText(simulationStop), ...
            'FixedStep', numberText(replay.sampleTime), ...
            'EnablePacing', 'on', ...
            'PacingRate', numberText(playbackRate));
        if ~options.SynchronizedViews
            for signalIndex = 1:numel(signalFields)
                field = signalFields{signalIndex};
                variableName = ['flipSimulink' upper(field(1)) field(2:end)];
                simObject = setVariable(simObject, variableName, replay.(field));
            end
        end
        simObject = setVariable(simObject, ...
            'flipSimulinkSampleTime', replay.sampleTime);
        simObject = setVariable(simObject, ...
            'flipSimulinkStartTime', simulationStart);
        simObject = setVariable(simObject, ...
            'flipSimulinkStopTime', replay.stopTime);
        simObject = setVariable(simObject, ...
            'flipSimulinkInitialTranslation', ...
            replay.translationData(selection.frameIndex, :));
        simObject = setVariable(simObject, ...
            'flipSimulinkInitialRotationYPR', ...
            replay.rotationYPRData(selection.frameIndex, :));
        simObject = setVariable(simObject, ...
            'flipSimulinkOperatorViewTranslation', ...
            replay.operatorViewTranslation);
        simObject = setVariable(simObject, ...
            'flipSimulinkOperatorViewRotation', ...
            replay.operatorViewRotation);

    end

    function restartReplay(~, ~)

        rebuildSimulation(replay.startTime, true);

    end

    function startFrameSource()
        endReached = false;
        requestedRenderTime = playbackStartTime;
        frameSource.Seek(playbackStartTime, warmupFrameCount);
    end

    function previousFrame(~, ~)

        selection = currentFrameSelection();
        targetIndex = max(1, selection.frameIndex - 1);
        rebuildSimulation(replay.time(targetIndex), true);

    end

    function nextFrame(~, ~)

        selection = currentFrameSelection();

        if selection.frameIndex >= numel(replay.time)

            return;

        end

        status = simulationStatus();

        if status == "running"

            pause(simulationObject);
            drawnow;
            status = simulationStatus();

        end

        if status == "initialized" || status == "paused"

            seeking = true;
            try
                step(simulationObject, 'NumberOfSteps', 1);
                if options.SynchronizedViews
                    renderPendingFrame(true);
                end
                refreshPlayer();
            catch exception
                finishSeeking();
                rethrow(exception);
            end
            finishSeeking();

        else

            targetIndex = selection.frameIndex + 1;
            rebuildSimulation(replay.time(targetIndex), true);

        end

    end

    function previousEvent(~, ~)

        jumpToEvent("previous");

    end

    function nextEvent(~, ~)

        jumpToEvent("next");

    end

    function jumpToEvent(direction)

        selection = currentFrameSelection();
        event = resolveReplayEvent(replay, selection.time, direction);

        if ~event.found

            statusLabel.Text = char(event.summary);
            return;

        end

        targetIndex = find(replay.time >= event.time, 1, 'first');

        if isempty(targetIndex)

            targetIndex = numel(replay.time);

        end

        rebuildSimulation(replay.time(targetIndex), true);
        statusLabel.Text = sprintf('Event %.6f s | %s', ...
            event.time, event.summary);

    end

    function changePlaybackRate(source, ~)

        playbackRate = double(source.Value);

        if ~isempty(simulationObject)

            simulationObject = setModelParameter( ...
                simulationObject, 'PacingRate', numberText(playbackRate));
            simulationControls.Simulation = simulationObject;

        end

        statusLabel.Text = sprintf('Playback rate set to %.2fx.', ...
            playbackRate);

    end

    function seekExactTime(~, ~)

        rebuildSimulation(exactTimeField.Value, true);

    end

    function previewTimeline(~, event)

        sliderIsMoving = true;
        selection = resolveTime(event.Value);
        timelineLabel.Text = formatTimelineLabel(selection);

    end

    function seekTimeline(source, ~)

        requestedTime = source.Value;
        sliderIsMoving = false;
        rebuildSimulation(requestedTime, true);

    end

    function selection = seekProgrammatically(requestedTime)

        rebuildSimulation(requestedTime, true);
        selection = currentSelection;

    end

    function simObject = getSimulationObject()

        simObject = simulationObject;

    end

    function refreshPlayer(~, ~)

        if closingPlayer || ~isvalid(playerFigure) || ...
                isempty(simulationObject)

            return;

        end

        if options.SynchronizedViews
            if endReached && simulationStatus() == "running"
                set_param(modelName, 'SimulationCommand', 'pause');
            end
            if endReached
                renderPendingFrame(true);
            end
            if toc(controlsClock) >= 0.10
                updateControls(currentSelection);
            end
            return;
        end

        selection = currentFrameSelection();
        currentSelection = selection;
        updateControls(selection);

    end

    function selection = currentFrameSelection()

        currentTime = currentSelection.time;

        if options.SynchronizedViews
            selection = currentSelection;
            return;
        end

        try

            candidateTime = double(simulationObject.Time);

            if isscalar(candidateTime) && isfinite(candidateTime)

                currentTime = candidateTime;

            end

        catch

        end

        selection = resolveTime(currentTime);

    end

    function updateControls(selection)

        controlsClock = tic;
        currentSelection = selection;
        exactTimeField.Value = selection.time;

        if ~sliderIsMoving

            timelineSlider.Value = selection.time;
            timelineLabel.Text = formatTimelineLabel(selection);

        end

        statusLabel.Text = sprintf( ...
            'Status: %s | pose: %s | speed: %.2fx', ...
            simulationStatus(), selection.poseStatus, playbackRate);
        flightState = resolveState(selection.time);
        if ~strcmp(stateLabel.Text, flightState.summary)
            stateLabel.Text = flightState.summary;
        end

        if any(flightState.table.IsAlert)

            stateLabel.FontColor = [0.75 0.05 0.05];

        else

            stateLabel.FontColor = [0.10 0.10 0.10];

        end

    end

    function receiveRenderedFrame(rgb, sourceTime)

        if closingPlayer || ~isvalid(playerFigure)
            return;
        end
        if sourceTime < requestedRenderTime - replay.sampleTime * 1e-6
            return;
        end
        % The display timer consumes RGB and its timestamp as one packet.
        pendingPacket = struct('rgb', rgb, 'time', sourceTime);
        pendingFrameAvailable = true;
        endReached = sourceTime >= replay.stopTime - replay.sampleTime * 1e-6;
        startQueuedRenderer();

    end

    function startQueuedRenderer()
        if closingPlayer || seeking || ~pendingFrameAvailable || ...
                isempty(renderTimer) || ~isvalid(renderTimer)
            return;
        end
        if strcmp(renderTimer.Running, 'off')
            start(renderTimer);
        end
    end

    function displayQueuedFrame(~, ~)
        if closingPlayer || seeking
            stop(renderTimer);
            return;
        end
        renderPendingFrame(false);
        if closingPlayer || ~isvalid(renderTimer)
            return;
        end
        if ~pendingFrameAvailable
            stop(renderTimer);
        end
    end

    function renderPendingFrame(forceDraw)
        if ~pendingFrameAvailable || closingPlayer || ~isvalid(playerFigure)
            return;
        end
        packet = pendingPacket;
        pendingFrameAvailable = false;
        selection = views.Update(packet.rgb, packet.time);
        currentSelection = selection;
        if toc(controlsClock) >= 0.10 || selection.frameIndex == selection.frameCount
            updateControls(selection);
        end
        if forceDraw
            drawnow nocallbacks;
        else
            drawnow;
        end

    end

    function status = simulationStatus()

        status = "inactive";

        if isempty(simulationObject)

            return;

        end

        try

            status = string(simulationObject.Status);

        catch

        end

    end

    function disposeSimulation()

        if isempty(simulationObject)

            return;

        end

        status = simulationStatus();

        if status ~= "inactive"

            try

                terminate(simulationObject);

            catch

                try

                    stop(simulationObject);

                catch

                end

            end

        end

        simulationObject = [];

    end

    function closePlayer(~, ~)

        closingPlayer = true;

        if ~isempty(updateTimer) && isvalid(updateTimer)

            stop(updateTimer);
            delete(updateTimer);

        end
        if ~isempty(renderTimer) && isvalid(renderTimer)
            stop(renderTimer);
            delete(renderTimer);
        end

        disposeSimulation();
        releaseEmbeddedModel();

        if isvalid(playerFigure)

            delete(playerFigure);

        end

    end

    function releaseEmbeddedModel()

        if options.SynchronizedViews && bdIsLoaded(modelName)
            sink = getSimulinkBlockHandle(modelName + "/Synchronized Frame Sink");
            if sink > 0
                set_param(sink, 'UserData', []);
            end
            source = getSimulinkBlockHandle(modelName + "/Replay Frame Source");
            if source > 0
                set_param(source, 'UserData', []);
            end
            close_system(modelName, 0);
        end

    end

end


function text = formatTimelineLabel(selection)

    text = sprintf('%.6f s | frame %d / %d | pose: %s', ...
        selection.time, selection.frameIndex, selection.frameCount, ...
        selection.poseStatus);

end


function text = numberText(value)

    text = sprintf('%.17g', value);

end


function modelPath = defaultModelPath(synchronizedViews)

    projectRoot = fileparts(fileparts(fileparts(mfilename('fullpath'))));
    if synchronizedViews
        modelPath = fullfile(projectRoot, 'results', 'exports', ...
            'FLIP_SynchronizedReplay.slx');
    else
        modelPath = fullfile(projectRoot, 'models', 'FLIP_UnrealReplay.slx');
    end

end


function validatePlayerEnvironment()

    if isempty(ver('simulink')) || ~license('test', 'Simulink')

        error('FLIP:MissingSimulink', ...
            'The FLIP replay controller requires Simulink.');

    end

    if isempty(which('uisimcontrols')) || isempty(which('simulation'))

        error('FLIP:UnsupportedInteractiveSimulink', [ ...
            'The FLIP replay controller requires MATLAB/Simulink R2024a ' ...
            'or later.']);

    end

end
