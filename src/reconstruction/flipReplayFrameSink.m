function flipReplayFrameSink(block)
% Deliver a rendered RGB frame and its log timestamp together.

    block.NumDialogPrms = 0;
    block.NumInputPorts = 2;
    block.NumOutputPorts = 0;
    block.SetPreCompInpPortInfoToDynamic;
    block.AllowSignalsWithMoreThan2D = true;
    block.InputPort(1).DirectFeedthrough = true;
    block.InputPort(2).DirectFeedthrough = true;
    block.InputPort(2).Dimensions = 1;
    block.InputPort(2).DatatypeID = 0;
    block.InputPort(2).Complexity = 'Real';
    block.InputPort(2).SamplingMode = 'Sample';
    block.SampleTimes = [-1 0];
    block.SimStateCompliance = 'DefaultSimState';
    block.RegBlockMethod('Outputs', @displayFrame);
end

function displayFrame(block)
    callback = get_param(block.BlockHandle, 'UserData');
    if isa(callback, 'function_handle')
        callback(block.InputPort(1).Data, block.InputPort(2).Data);
    end
end
