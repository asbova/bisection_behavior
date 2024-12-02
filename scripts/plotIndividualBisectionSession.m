function plotIndividualBisectionSession(trialData, saveDirectory)

% 
% 
% INPUTS:
%   trialData:          data structure with behavioral data for each trial, each session, each mouse
%   saveDirectory:      directory pathway where figures will be saved
%
% OUTPUTS:
%   figure

    


    mouseIDs = fieldnames(trialData);

    for iMouse = 1 : length(mouseIDs)
        currentMouse = char(mouseIDs(iMouse));
      
        % Set up figure;
        figure('Units', 'Normalized', 'OuterPosition', [0, 0.04, 0.6, 0.95]);
        nSessions = sum(~cellfun('isempty', {trialData.(currentMouse)}));
        nSubplotsY = 2;
        nSubplotsX = nSessions;

        % Plot data.
        plotPsychometricFunction(trialData, currentMouse);
        plotOutcome(trialData, currentMouse);
        saveas(gcf, fullfile(saveDirectory, sprintf('%s_Bisection.png', currentMouse)));
        close all

        % Plot accuracy
    end

end



function plotPsychometricFunction(trialData, mouseID)

    rowsWithData = find(~cellfun('isempty', {trialData.(mouseID)}));
    nSessions = length(rowsWithData);
    idxSubplot = 1;
    for iSession = 1 : nSessions

        currentSessionData = trialData(rowsWithData(iSession)).(mouseID);

        intervals = unique([currentSessionData.programmedDuration]);
        pLong = zeros(1, length(intervals));
        nTrialsInterval = zeros(1, length(intervals));
        for jInterval = 1 : length(intervals)          
            currentTrialData = currentSessionData(cellfun(@(x) x == intervals(jInterval), {currentSessionData.programmedDuration}));
            pLong(1, jInterval) = sum(cellfun(@(x) x == 2, {currentTrialData.choicePort})) / size(currentTrialData, 2);
            nTrialsInterval(1, jInterval) = size(currentTrialData, 2);
        end

        nLongResponses = pLong .* nTrialsInterval;

        % Plot probability of a long response at each interval.
        subplot(nSessions, 2, idxSubplot);
        cla; hold on;
        plot(intervals / 1000, pLong, 'ko-', 'MarkerFaceColor', 'k');

        % Fit a psychometric function to the data.
        logistic = @(b, x) 1 ./ (1 + exp(-(x - b(1)) / b(2)));
        initialGuess = [mean(intervals / 1000), 50];                       % bias, slope
        options = optimset('TolFun', 1e-6, 'MaxIter', 1000);
        params = fminsearch(@(b) sum((logistic(b, intervals / 1000) - pLong).^2), initialGuess, options);
        tBias = params(1);
        slope = params(2);

        % Plot the fitted logistic function.
        intervalsFine = linspace(min(intervals / 1000), max(intervals / 1000), 100);
        pLongFit = logistic(params, intervalsFine);
        plot(intervalsFine, pLongFit, 'r-', 'LineWidth', 2);

        % Figure labels
        legend('Data', 'Fitted Logistic Curve', 'Location', 'southeast')
        text(0.7, 0.9, ['Bias: ', num2str(tBias), ' s'])
        text(0.7, 0.8, ['Slope: ', num2str(slope)])
        xlabel('Time Interval (s)')
        xticks(sort([intervals / 1000 1.5]));
        xticklabels({0.6, '', '', '' 1.5 '' '' '' 2.4})
        xlim([0.4 2.6])
        ylabel('P(Long Choice)')
        yticks([0 0.5 1]);
        ylim([0 1])

        idxSubplot = idxSubplot + 2;
    end
end




function plotOutcome(trialData, mouseID)

    rowsWithData = find(~cellfun('isempty', {trialData.(mouseID)}));
    nSessions = length(rowsWithData);

    percentOutcome = NaN(3, 1);
    idxSubplot = 2;
    for iSession = 1 : nSessions

        currentSessionData = trialData(rowsWithData(iSession)).(mouseID);

        for jOutcome = 1 : 3
            percentOutcome(jOutcome, 1) = (sum(cellfun(@(x) x == jOutcome, {currentSessionData.outcome})) / size(currentSessionData, 2)) * 100;
        end

        subplot(nSessions, 2, idxSubplot);
        cla; hold on;
        b = bar(percentOutcome);
        b.FaceColor = 'flat';
        b.CData(1,:) = [76 153 0] ./ 255;
        b.CData(2,:) = [204 0 0] ./ 255;
        b.CData(3,:) = [255 178 102] ./ 255;
        xlim([0.5 3.5])
        xticks(1:3);
        xticklabels({'Correct', 'Incorrect', 'Premature'});
        ylabel('Percent of Trials');

        idxSubplot = idxSubplot + 2;

    end

end