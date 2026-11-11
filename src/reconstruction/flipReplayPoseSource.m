function flipReplayPoseSource(block)
% Supply body and propeller poses for the current replay frame.

    block.NumDialogPrms = 1;
    block.NumInputPorts = 0;
    block.NumOutputPorts = 8;
    dimensions = {3, 3, 1, 1, [17 3], [17 3], [17 3], 1};
    for index = 1:block.NumOutputPorts
        block.OutputPort(index).Dimensions = dimensions{index};
        block.OutputPort(index).DatatypeID = 0;
        block.OutputPort(index).Complexity = 'Real';
        block.OutputPort(index).SamplingMode = 'Sample';
    end
    block.SampleTimes = [block.DialogPrm(1).Data 0];
    block.SimStateCompliance = 'DefaultSimState';
    block.RegBlockMethod('Start', @startReplay);
    block.RegBlockMethod('Outputs', @readFrame);
end

function startReplay(block)
    source = get_param(block.BlockHandle, 'UserData');
    source.Start();
end

function readFrame(block)
    source = get_param(block.BlockHandle, 'UserData');
    values = source.Read(block.CurrentTime);
    for index = 1:block.NumOutputPorts
        block.OutputPort(index).Data = values{index};
    end
end
