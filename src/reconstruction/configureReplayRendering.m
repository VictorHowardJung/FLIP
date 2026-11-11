function configureReplayRendering(world, quality)
% Set a fixed Unreal rendering profile during scene initialization.

    arguments
        world (1, 1)
        quality (1, 1) string {mustBeMember(quality, ...
            ["low", "medium", "high", "epic", "cinematic"])} = "epic"
    end

    world.GraphicsQuality = quality;
end
