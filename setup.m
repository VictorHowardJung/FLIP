function setup()
% Initialize project paths and validate the UAV Toolbox license.

    rootDir = fileparts(mfilename('fullpath'));

    addpath(genpath(fullfile(rootDir, 'src')));


    toolboxInfo = ver('uav');

    if isempty(toolboxInfo) || exist('ulogreader', 'file') ~= 2

        error('FLIP:MissingUAVToolbox', [ ...
            'FLIP requires UAV Toolbox to read PX4 ULog files.\n' ...
            'Install UAV Toolbox and run RUNME.m again.']);

    end

    if ~license('test', 'UAV_Toolbox')

        error('FLIP:UAVToolboxLicenseUnavailable', [ ...
            'A UAV Toolbox license is not currently available.\n' ...
            'Check your MATLAB or campus license and run RUNME.m again.']);

    end

    fprintf('FLIP environment initialized.\n');
    fprintf('MATLAB release : %s\n', version('-release'));
    fprintf('Log backends   : ULog / MAVLink TLOG, UAV Toolbox %s\n', toolboxInfo.Version);

end
