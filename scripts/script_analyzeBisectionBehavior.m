% script_analyzeSwitchBehavior

cd /Users/asbova/Documents/MATLAB
addpath(genpath('./bisection_behavior'))
addpath('./bisection_behavior/util')

% Identify key directories
codePathway = './bisection_behavior/scripts';                            % code
medpcDataPathway = './bisection_behavior/data/medpc';                    % medpc files
resultsPathway = './bisection_behavior/results/training_behavior/test'; % folder to save results
if ~exist(resultsPathway, 'dir')
    mkdir(resultsPathway)
else
    % Directory already exists.
end

% Identify the sessions to be analyzed using the getAnProfile function or manually specify.
if exist(fullfile(codePathway, 'getMouseSessions.m'), 'file') == 2
    [protocols, group] = getMouseSessions();
else
    protocols = {'Switch_6L18R_viITI', 'Switch_18L6R_viITI'}; % Specify the medpc protocols or leave empty.
    mouseIDs = {'ASB15', 'ASB16', 'ASB17', 'ASB18'};          % Specify the mouse ids or leave empty.
    dateRange = {'2024-06-11', '2024-06-13'};                 % Specify the start date or start and end dates or leave empty.
    group = [];
end

% Parse out medPC data into a structure trialData.
if isempty(group)
    mpcParsed = getDataIntr(medpcDataPathway, protocols, mouseIDs, dateRange);
else
    mpcParsed = getDataIntr(medpcDataPathway, protocols, group);
end
trialDataStructure = getTrialDataBisection(mpcParsed);

% Testing Protocol - Plot each session for each mouse individually (psychometric function, accuracy, percent premature)
plotIndividualBisectionSession(trialDataStructure, resultsPathway)





eventDatapath = '/Volumes/BovaData4/BisectionTest/TEST4_2024-11-13_12-36-16_RD2';
rawDataFolder = 'TEST4_2024-11-13_12-36-16_RD2';

events = getOephysEventsBisection(eventDatapath, mpcParsed, rawDataFolder);