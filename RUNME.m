% Main entry point and user menu for FLIP.

clear;
clc;
close all;

setup;

fprintf('\n');
fprintf('====================================\n');
fprintf('                FLIP                \n');
fprintf(' Flight Log Interpretation Platform \n');
fprintf('====================================\n\n');

fprintf('1. Analyze flight log (.ulg / .tlog)\n');
fprintf('2. Exit\n\n');

choiceText = input('Select an option: ', 's');
choice = str2double(strtrim(choiceText));

switch choice

    case 1

        fprintf('\n');
        fprintf('Select your log file.\n');

        [fileName, filePath] = uigetfile( ...
            {'*.ulg;*.tlog', 'Flight Logs (*.ulg, *.tlog)'; ...
             '*.ulg', 'PX4 ULog Files (*.ulg)'; ...
             '*.tlog', 'MAVLink Telemetry Logs (*.tlog)'}, ...
            'Select Flight Log');

        if isequal(fileName, 0)

            fprintf('No file selected.\n');
            return;

        end

        logFile = fullfile(filePath, fileName);

        fprintf('\nSelected file:\n%s\n\n', logFile);

        try

            flightData = loadFlightLog(logFile);
            flightData = preprocessFlightData(flightData);

        catch exception

            fprintf(2, 'FLIP could not load the selected flight log.\n');
            fprintf(2, '%s\n', exception.message);
            return;

        end

        fprintf('Flight log loaded (%.3f s).\n', ...
            flightData.metadata.duration);

        fprintf('\nAnalysis output options:\n');
        fprintf('1. Open plot windows, then save\n');
        fprintf('2. Save without opening plot windows\n');
        outputChoice = strtrim(input('Select an output option [1]: ', 's'));
        while ~isempty(outputChoice) && ~any(strcmp(outputChoice, {'1', '2'}))
            fprintf('Enter 1 or 2.\n');
            outputChoice = strtrim(input('Select an output option [1]: ', 's'));
        end
        plotVisibility = "on";
        if strcmp(outputChoice, '2')
            plotVisibility = "off";
        end

        try

            analysisResult = evaluateTrackingPerformance(flightData);

        catch exception

            fprintf(2, 'FLIP could not evaluate the selected flight.\n');
            fprintf(2, '%s\n', exception.message);
            return;

        end

        try

            outputSession = createAnalysisOutputSession();
            [figureHandles, savedFigureFiles, combinedPlotPdf] = ...
                outputFlightAnalysis(flightData, analysisResult, logFile, ...
                    outputSession.originalDirectory, plotVisibility);
            figureOutputDirectory = outputSession.originalDirectory;
            analysisFigures = gobjects(0, 1);
            if plotVisibility == "on"
                analysisFigures = reshape( ...
                    cell2mat(struct2cell(figureHandles)), [], 1);
            end
            fprintf('Interval output directory for this run:\n%s\n', ...
                outputSession.intervalDirectory);

        catch exception

            fprintf(2, 'FLIP could not create or save the flight plots.\n');
            fprintf(2, '%s\n', exception.message);

        end

        fprintf('\nOptional interactive interval re-analysis:\n');
        fprintf('Enter y to open it, or press Enter to continue.\n');
        intervalChoice = strtrim(input('Selection: ', 's'));

        if strcmpi(intervalChoice, 'y')
            if ~exist('outputSession', 'var')
                outputSession = createAnalysisOutputSession();
            end
            intervalFigure = createIntervalAnalysisWindow(flightData, 'on', ...
                PlotVisibility=plotVisibility, OutputSession=outputSession);

            if exist('analysisFigures', 'var')
                analysisFigures = analysisFigures( ...
                    isgraphics(analysisFigures, 'figure'));
                analysisFigures(end + 1, 1) = intervalFigure;
            else
                analysisFigures = intervalFigure;
            end
        end

        fprintf('\nFlight reconstruction options:\n');
        fprintf('1. 2D + 3D simulation\n');
        fprintf('2. 3D only \n');
        fprintf('Press Enter to skip reconstruction.\n');
        unrealChoice = strtrim(input('Select a replay option: ', 's'));

        if strcmp(unrealChoice, '2') && ...
                exist('analysisFigures', 'var')

            analysisFigures = analysisFigures( ...
                isgraphics(analysisFigures, 'figure'));

            if ~isempty(analysisFigures)
                set(analysisFigures, 'Visible', 'off');
                drawnow;
                restoreAnalysisFigures = onCleanup(@() ...
                    restoreVisibleFigures(analysisFigures));
                fprintf(['Open FLIP windows are temporarily hidden during ' ...
                    '3D replay to reduce graphics contention.\n']);
            end

        end

        try

            switch unrealChoice

                case '1'

                    [replayFigure, synchronizedReplay, ...
                        synchronizedModelPath] = ...
                        createSimulinkReplayPlayer( ...
                            flightData, SynchronizedViews=true, SampleTime=1 / 15);

                case '2'

                    [simulinkOutput, simulinkReplay, ...
                        simulinkModelPath] = ...
                        runSimulinkUnrealReplay( ...
                            flightData, ...
                            OpenModel=false, ...
                            OpenScopes=false);

                otherwise

                    if ~isempty(unrealChoice)

                        fprintf('Unknown 3D option. Reconstruction skipped.\n');

                    end

            end

        catch exception

            fprintf(2, ...
                'FLIP could not open the 3D reconstruction.\n');
            fprintf(2, '%s\n', exception.message);

        end

        if exist('restoreAnalysisFigures', 'var')
            clear restoreAnalysisFigures;
        end


    case 2

        fprintf('\nExiting FLIP.\n');


    otherwise

        fprintf('\nInvalid selection.\n');

end


function restoreVisibleFigures(figureHandles)

    figureHandles = figureHandles(isgraphics(figureHandles, 'figure'));

    if ~isempty(figureHandles)
        set(figureHandles, 'Visible', 'on');
        drawnow;
    end

end
