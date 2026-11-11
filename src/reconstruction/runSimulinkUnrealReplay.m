function [simulationOutput, replay, modelPath] = ...
        runSimulinkUnrealReplay(flightData, options)
% Run UAV Toolbox Simulink/Unreal playback on the source-log time base.

    arguments

        flightData (1, 1) struct
        options.SampleTime (1, 1) double {mustBeFinite, mustBePositive} = 1 / 60
        options.MaxInterpolationGap (1, 1) double ...
            {mustBeFinite, mustBePositive} = 0.25
        options.Scene (1, 1) string = "Airport"
        options.OpenModel (1, 1) logical = false
        options.OpenScopes (1, 1) logical = false
        options.RebuildModel (1, 1) logical = false
        options.ViewHeadingDegrees (1, 1) double {mustBeFinite} = 0
        options.GraphicsQuality (1, 1) string {mustBeMember(options.GraphicsQuality, ...
            ["low", "medium", "high", "epic", "cinematic"])} = "epic"

    end

    worldOffset = getSimulinkUnrealSceneOffset(options.Scene);
    replay = prepareSimulinkUnrealReplay( ...
        flightData, ...
        SampleTime=options.SampleTime, ...
        MaxInterpolationGap=options.MaxInterpolationGap, ...
        WorldOffset=worldOffset, ViewHeadingDegrees=options.ViewHeadingDegrees);
    modelPath = defaultModelPath();

    if options.RebuildModel || ~isfile(modelPath) || ...
            ~modelSupportsLoggedPropellers(modelPath)

        modelPath = buildSimulinkUnrealReplayModel( ...
            OutputFile=string(modelPath), Scene=options.Scene, ...
            GraphicsQuality=options.GraphicsQuality);

    end

    assignReplayVariables(replay);
    [modelDirectory, modelName] = fileparts(modelPath);
    addpath(modelDirectory);
    load_system(modelPath);
    if getSimulinkBlockHandle(modelName + "/Rendering Quality") < 0
        close_system(modelName, 0);
        modelPath = buildSimulinkUnrealReplayModel( ...
            OutputFile=string(modelPath), Scene=options.Scene, ...
            GraphicsQuality=options.GraphicsQuality);
        load_system(modelPath);
    end
    set_param(modelName + "/Rendering Quality", 'InitScriptText', ...
        sprintf('configureReplayRendering(World, "%s");', options.GraphicsQuality));
    replay.metadata.graphicsQuality = options.GraphicsQuality;
    sceneBlock = modelName + "/Simulation 3D Scene Configuration";
    set_param(sceneBlock, 'SceneDesc', char(options.Scene));

    if options.OpenModel

        open_system(modelName);

    end

    if options.OpenScopes

        open_system(modelName + "/Speed Scope");
        open_system(modelName + "/Altitude AGL Scope");
        open_system(modelName + "/Attitude YPR Scope");

    end

    fprintf('\nStarting UAV Toolbox Simulink Unreal replay.\n');
    fprintf('ULog time       : %.3f to %.3f s\n', ...
        replay.startTime, replay.stopTime);
    fprintf('Replay rate     : %.1f samples/s\n', 1 / replay.sampleTime);
    fprintf('Wall-clock pace : 1.0x (one log second per real second)\n');
    fprintf('Ground reference: initial position = 0 m AGL\n');
    fprintf('Camera          : fixed operator viewpoint\n');
    fprintf('Altitude scale  : 1.0x (true logged metres)\n');
    fprintf('Scene offset    : [%.1f %.1f %.1f] m\n', worldOffset);
    fprintf('Model           : %s\n', modelPath);
    fprintf('Speed source    : logged vx, vy, vz magnitude\n');
    fprintf(['Propellers      : actuator_motors while armed; ' ...
        'stop at logged disarm\n']);
    fprintf(['Environment     : illustrative Unreal scene; ' ...
        'not flight-site evidence\n']);

    simulationOutput = sim(modelName);

end


function supported = modelSupportsLoggedPropellers(modelPath)

    try

        [~, modelName] = fileparts(modelPath);
        alreadyLoaded = bdIsLoaded(modelName);
        load_system(modelPath);
        block = modelName + "/Logged Propeller Transform";
        supported = getSimulinkBlockHandle(block) ~= -1 && ...
            strcmp(get_param(block, 'ActorTag'), 'FLIPVehicle') && ...
            strcmp(get_param(block, 'NumberOfParts'), '17');

        if ~alreadyLoaded

            close_system(modelName, 0);

        end

    catch

        supported = false;

    end

end


function assignReplayVariables(replay)

    assignin('base', 'flipSimulinkTranslation', replay.translation);
    assignin('base', 'flipSimulinkRotationYPR', replay.rotationYPR);
    assignin('base', 'flipSimulinkSpeed', replay.speed);
    assignin('base', 'flipSimulinkAltitude', replay.altitude);
    assignin('base', 'flipSimulinkValidPose', replay.validPose);
    assignin('base', 'flipSimulinkArmed', replay.armed);
    assignin('base', 'flipSimulinkActorTranslation', ...
        replay.actorTranslation);
    assignin('base', 'flipSimulinkActorRotation', replay.actorRotation);
    assignin('base', 'flipSimulinkActorScale', replay.actorScale);
    assignin('base', 'flipSimulinkSampleTime', replay.sampleTime);
    assignin('base', 'flipSimulinkStartTime', replay.startTime);
    assignin('base', 'flipSimulinkStopTime', replay.stopTime);
    assignin('base', 'flipSimulinkInitialTranslation', ...
        replay.initialTranslation);
    assignin('base', 'flipSimulinkInitialRotationYPR', ...
        replay.initialRotationYPR);
    assignin('base', 'flipSimulinkOperatorViewTranslation', ...
        replay.operatorViewTranslation);
    assignin('base', 'flipSimulinkOperatorViewRotation', ...
        replay.operatorViewRotation);

end


function modelPath = defaultModelPath()

    projectRoot = fileparts(fileparts(fileparts(mfilename('fullpath'))));
    modelPath = fullfile(projectRoot, 'models', 'FLIP_UnrealReplay.slx');

end
