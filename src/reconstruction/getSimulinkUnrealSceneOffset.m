function offset = getSimulinkUnrealSceneOffset(scene)
% Return the presentation-only world offset required by an Unreal scene.

    arguments

        scene (1, 1) string

    end

    switch scene

        case "Airport"

            % The generic Airport runway spans approximately X=3532..6550 m.
            offset = [5000 0 0];

        otherwise

            offset = [0 0 0];

    end

end
