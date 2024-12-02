function trialStructureMPC = getTrialDataBisection(mpcParsed)
%
%
% Parses medpc output data into a structure containing timestamps for key behavioral events for each trial in the 2-8 discrimination task.
% 
% INPUTS:
%   mpcParsed:              structure containing all parsed medpc output for each session
%
% OUTPUTS:
%   trialStructureMPC:      structure containing trial by trial timestamps of behavioral events and trial information
%                           (e.g., interval duration, opto on or off, etc.)
%
% MPC Data Arrays:
%    D       Time of cues off array
%    F       Back Response In array
%    G       Back Response Out array
%    H       Trial Start time record array
%    L       Log trial outcomes.
%    M       Premature trial tracker (1 = no, 2 = yes)
%    N       RIGHT NP response time record array
%    O       RIGHT NP release time record array
%    P       LEFT NP response time record array
%    Q       LEFT NP release time record array
%    S       Trial End time record array
%    T       Trial duration record array
%    U       ITI record array
%    V       Terminal side choice array
%    W       Pellet dispense time record array
%    X       milli second Timer for recording events
%    Y       Reward zone in record array
%    Z       Reward zone out record array       


    trialStructureMPC = [];
    
    uniqueSubjects = unique({mpcParsed.Subject});
    nmpcType = min(cellfun(@length, {mpcParsed.H}), cellfun(@length, {mpcParsed.S})) > 0; % Check that there are trials.
    
    for iMouse = 1 : size(uniqueSubjects,2)
        subjectIndex = strcmp(uniqueSubjects(iMouse), {mpcParsed.Subject}) & nmpcType;
        subjectLineIndex = find(subjectIndex);
        nDays = sum(subjectIndex);
        currentMouse = char(uniqueSubjects(iMouse));  
    
        for jDay = 1 : nDays
            lineIndex = subjectLineIndex(jDay);
            if contains(mpcParsed(lineIndex).MSN,'SLLR')           % Left nosepoke is rewarded for short trials; right for long trials.
                type = 0;
            elseif contains(mpcParsed(lineIndex).MSN,'LLSR')       % Right nosepoke is rewarded for short trials; left for long trials.
                type = 1;
            else
                type = NaN;
            end
                
            ITIduration = mpcParsed(lineIndex).U';
            trialStart = mpcParsed(lineIndex).H';
            trialEnd = mpcParsed(lineIndex).S'; 
            trialStart = trialStart(1 : length(trialEnd));
            trialType = mpcParsed(lineIndex).T';                   % Programmed duration for the trial.
            trialType = trialType(1 : length(trialEnd));
            reward = mpcParsed(lineIndex).W';
                
            choicePort = mpcParsed(lineIndex).V';                  % 1 = left, 2 = right
            responseLeft = mpcParsed(lineIndex).P'; 
            releaseLeft = mpcParsed(lineIndex).Q';
            responseRight = mpcParsed(lineIndex).N'; 
            releaseRight = mpcParsed(lineIndex).O';
            responseBack = mpcParsed(lineIndex).F'; 
            % releaseBack = mpcParsed(lineIndex).G'; 
            % responseReward = mpcParsed(lineIndex).Y';
            % releaseReward = mpcParsed(lineIndex).Z';
    
            trialOutcome = mpcParsed(lineIndex).L';                % 1 = correct trial; 2 = incorrect trial; 3 = premature tiral
            if type == 0                                           % 0 indicates that a short latency (2s) trial is rewarded at the left nose poke
                responseShort = responseLeft;
                releaseShort = releaseLeft;    
            elseif type == 1                                       % 1 indicates that a short latency (2s) trial is rewarded at the right nose poke
                responseShort = responseRight;
                releaseShort = releaseRight;          
            end
            
            % if numel(responseShort) == numel(releaseShort)
            %     durationShortResponse = releaseShort - responseShort;
            % elseif numel(responseShort) == numel(releaseShort) + 1 && responseShort(end) > releaseShort(end)
            %     durationShortResponse = releaseShort - responseShort(1 : end-1);
            % end
                
            trialStructure = struct;
            nTrials = min(length(trialStart), length(trialEnd));
            for kTrial = 1 : nTrials
               
                currentTrialStart = trialStart(kTrial);                                                   % Back NP light on
                currentTrialEnd = trialEnd(kTrial);
                trialStructure(kTrial).trialStart = currentTrialStart;
                trialStructure(kTrial).trialEnd = currentTrialEnd;
                trialStructure(kTrial).trialDuration = currentTrialEnd - currentTrialStart;
                trialStructure(kTrial).ITI = ITIduration(kTrial);
                
                x = responseBack - currentTrialStart;
                trialStructure(kTrial).initiationReactionTime = min(x(x >= 0));                           % Get the time between when trial available and back response to initiate trial.
                realTrialStart = trialStructure(kTrial).initiationReactionTime +  currentTrialStart;      % Add the reaction time to trial start (when back light turned on) to get the real trial start. 
                trialStructure(kTrial).realTrialStart = realTrialStart;
                
                trialStructure(kTrial).programmedDuration = trialType(kTrial);                            % (milliseconds)
                trialStructure(kTrial).outcome = trialOutcome(kTrial);
                
                trialStructure(kTrial).leftResponseTime = responseLeft(responseLeft > realTrialStart & responseLeft <= currentTrialEnd) - realTrialStart;
                trialStructure(kTrial).leftReleaseTime = releaseLeft(releaseLeft > realTrialStart & releaseLeft <= currentTrialEnd) - realTrialStart;
                trialStructure(kTrial).rightResponseTime = responseRight(responseRight > realTrialStart & responseRight <= currentTrialEnd) - realTrialStart;
                trialStructure(kTrial).rightReleaseTime = releaseRight(releaseRight > realTrialStart & releaseRight <= currentTrialEnd) - realTrialStart;              
                if type == 0
                    trialStructure(kTrial).ShortResponse = trialStructure(kTrial).leftResponseTime;
                    trialStructure(kTrial).LongResponse = trialStructure(kTrial).rightResponseTime;
                else
                    trialStructure(kTrial).ShortResponse = trialStructure(kTrial).rightResponseTime;
                    trialStructure(kTrial).LongResponse = trialStructure(kTrial).leftResponseTime;
                end

                trialStructure(kTrial).choicePort = choicePort(kTrial);
      
                if trialOutcome(kTrial) == 3
                    trialStructure(kTrial).trialEndReactionTime = NaN;
                else
                    startPoke = min(responseBack(responseBack >= trialStart(kTrial)));                                                      % Timestamp of first back poke after back nosepoke light on.
                    durationElapsed = startPoke + (trialType(kTrial) ./ 1000);                                                              % Time that the duration elapsed.
                    potentialRTs = [min(responseLeft(responseLeft >= durationElapsed)) min(responseRight(responseRight >= durationElapsed))];   % Find first responses after duration elapsed.
                    trialStructure(kTrial).trialEndReactionTime = min(potentialRTs) - durationElapsed; 
                end
    
                trialStructure(kTrial).reward = reward(reward > realTrialStart & reward <= currentTrialEnd + 0.2) - realTrialStart;
            end

            trialStructure(1).mpc = mpcParsed(lineIndex); 
            trialStructureMPC(jDay).(currentMouse) = trialStructure; 

        end
    
    end
    
end