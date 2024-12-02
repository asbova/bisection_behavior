function events = getOephysEventsBisection(eventDatapath, mpcParsed, rawDataFolder)
%
%
%
% INPUTS:
%   eventDatapath:          full file pathway of open ephys folder (string)
%   mpcParsed:              parsed medpc structure
%   rawDataFolder:          name of open ephys folder (string)
%
% OUTPUTS:
%   events:
%


    eventRecordType = {...
    '1 0 0 0 0', 'SESSION START'; ...
    '0 1 0 0 0', 'BACK NOSEPOKE LIGHT ON'; ...
    '0 0 1 0 0', 'BACK NOSEPOKE LIGHT OFF'; ...
    '0 0 0 1 0', 'ITI START'; ...
    '0 0 0 0 1', 'ITI END'; ...
    '1 1 0 0 0', 'CUES ON'; ...
    '1 0 1 0 0', 'CUES OFF'; ...
    '1 0 0 1 0', 'REWARD DISPENSE'; ...
    '1 0 0 0 1', 'TRIAL END'; ...
    '1 1 1 0 0', 'LEFT RESPONSE'; ...
    '1 1 0 1 0', 'LEFT RELEASE'; ...
    '1 1 0 0 1', 'RIGHT RESPONSE'; ...
    '1 1 1 1 0', 'RIGHT RELEASE'; ...
    '1 1 1 1 1', 'BACK RESPONSE'; ...
    '0 1 1 0 0', 'BACK RELEASE'; ...
    '0 1 0 1 0', 'REWARD ENTRY'; ...
    '0 1 0 0 1', 'REWARD EXIT';... 
    '0 0 1 1 1', 'TIMEOUT START';...
    '0 1 0 1 1', 'TIMEOUT END';...
    };
        
    eventTypeDecimal = cellfun(@(x) bin2dec(fliplr(x)), eventRecordType(:,1));                 % Convert binary event to decimal.
    eventRecordType(:, 3) = num2cell(eventTypeDecimal);
    
    eventData = readOEphys(eventDatapath, 'events', rawDataFolder);
    [~, folderName, ~] = fileparts(eventDatapath);
    fprintf('\n')
    fprintf('%s \n',folderName)
    fprintf('\n')
    
    % Re-align event time stamps to be 0 at processor 100 (FPGA buffer time)
    startTick = eventData.startTime;                                                                
    eventTimestamps = double(eventData.Timestamps) - startTick;
    evtDataMod = double(eventData.Data);   
      
    % Check for glitches (single channel rise/fall in 1 tick).
    eventDebug = [];                                                                                
    for iChannel = [1 3:6]
        fallIndex = find(eventData.Data == -iChannel);
        riseIndex = find(eventData.Data == iChannel);      
        if length(fallIndex) + 1 == length(riseIndex) && any(riseIndex(1) == (1:8))                 % Some data have rise glitch on first event, if it happens within first 8 events, remove it.
            riseIndex = riseIndex(2 : end);
        end
        pulseWidth = eventTimestamps(riseIndex) - eventTimestamps(fallIndex);
        glitchIndex = zeros(length(pulseWidth),1);
        glitchIndex(pulseWidth == 1) = 1;
        eventDebug = [eventDebug; [evtDataMod(fallIndex) eventTimestamps(fallIndex) eventTimestamps(riseIndex) pulseWidth glitchIndex]];
    end
    [~, sortIndex]= sort(eventDebug(:,2));                                                          % Sort by timestamp.
    eventDebug = eventDebug(sortIndex,:); 
    fprintf('%d electrical glitches removed \n', ~nnz(eventDebug(:,4)))                             % Remove glitches.
    eventDebug(eventDebug(:,4) == 1, :) = [];
    
    % Find split events for both rise and fall.
    eventFallTimestamps = eventDebug(:,2);
    splitTimestampIndex = find(diff(eventFallTimestamps) == 1);
    for iTimestamp = 1 : length(splitTimestampIndex)
        allIndex = eventFallTimestamps(splitTimestampIndex(iTimestamp)) == eventFallTimestamps | eventFallTimestamps(splitTimestampIndex(iTimestamp))+1 == eventFallTimestamps;
        eventDebug(allIndex,2) = eventFallTimestamps(splitTimestampIndex(iTimestamp));
    end
    eventRiseTimestamps = eventDebug(:,3);
    splitTimestampIndex = find(diff(eventRiseTimestamps) == 1);
    for iTimestamp = 1 : length(splitTimestampIndex)
        eventSplitTimestamps = eventRiseTimestamps(splitTimestampIndex(iTimestamp));
        allIndex = find(eventSplitTimestamps == eventRiseTimestamps | eventSplitTimestamps+1 == eventRiseTimestamps);
        if isscalar(unique(eventDebug(allIndex,2)))
            eventDebug(allIndex,3) = eventSplitTimestamps;
        else
            disp('e')
        end
    end
    
    allChannelEvents = eventDebug;
    allChannelEvents(:, 6) = allChannelEvents(:,1);
    allChannelEvents(allChannelEvents(:,1) == -1, 1) = -2;                                      % Replace channel 1 to 2
    allChannelEvents(:,1) = abs(allChannelEvents(:,1)) - 1;                                     % Change channel range from 2-6 to 1-5.
    uniqueTimestamps = unique(allChannelEvents(:, 2:3));
    
    % Track event channel status.
    eventType = '00000';
    sampleRate = 30000;
    eventTT = zeros(length(uniqueTimestamps), 4);
    for iEvent = 1 : length(uniqueTimestamps)
        timestampOnIndex = allChannelEvents(uniqueTimestamps(iEvent) == allChannelEvents(:,2), 1);
        timestampOffIndex = allChannelEvents(uniqueTimestamps(iEvent) == allChannelEvents(:,3), 1);
        eventType(timestampOnIndex) = '1';
        eventType(timestampOffIndex) = '0';
        eventTT(iEvent,1) = double(uniqueTimestamps(iEvent)) / sampleRate;
        eventTT(iEvent,2) = bin2dec(eventType);
        eventTT(iEvent,3) = uniqueTimestamps(iEvent);
        pulseWidth = allChannelEvents(uniqueTimestamps(iEvent) == allChannelEvents(:,2),4);
        if ~isempty(pulseWidth)
            eventTT(iEvent,4) = pulseWidth(1);
        end
    end    
    
    events = struct;
    uniqueType = unique(eventTT(:, 2));
    uniqueType = uniqueType(uniqueType > 0);
    for iType = 1 : length(uniqueType)
        events.(sprintf('evt%d',uniqueType(iType))).TS = eventTT(uniqueType(iType) == eventTT(:,2), 1);
        if any(eventTypeDecimal == uniqueType(iType))
            events.(sprintf('evt%d',uniqueType(iType))).type = eventRecordType{eventTypeDecimal == uniqueType(iType), 2};
        else
            events.(sprintf('evt%d', uniqueType(iType))).type = 'No defined event type';
            warning(sprintf('no defined type - evt%d', uniqueType(iType)))
        end
    end
    
    % ADD BACK IN FOR FIBER PHOTOMETRY TTL SIGNAL.
    % ttl_val = abs(mode(eventData.Data));    % if use the other arduino board for pigtail commutator it will be -8/8 instead of -2/2
    % led_ttl = eventTimestamps(eventData.Data == ttl_val);
    % if ~isempty(led_ttl)
    %     events.evt32.ts = double(led_ttl)./sampleRate;
    %     events.evt32.type = 'LED TTL';
    % end
    
    eventNames = fieldnames(events);
    for iType = 1 : length(eventNames)
        fprintf('%s: %s - %d events\n', eventNames{iType}, events.(eventNames{iType}).type, length(events.(eventNames{iType}).TS))
    end
    
    if nargin == 1
        return
    end
    
    
    % Check oephys events against MPC data.
    mouseID = regexp(folderName, '^\w+(?=_\d{4})', 'match', 'once');
    dateString = regexp(folderName, '(?<=_)\d{4}-\d{2}-\d{2}(?=_\d{2})', 'match', 'once');
    
    dateStringConverted = string(datetime(dateString), 'MM/dd/yy');
    matchingMpcIndex = find(strcmp(dateStringConverted, {mpcParsed.StartDate}) & strcmp(mouseID, {mpcParsed.Subject}));    
    
    if isempty(matchingMpcIndex)
        fprintf('NO MATCHING MPC FOUND! \n')
        return
    end
    mpcParsedMatch = mpcParsed(matchingMpcIndex(1));
    maxDeviationSet = 0.3;                                                                              % maximum allowed deviation
    eventsToCheck = {2, 'H'; 17, 'S'; 9, 'W'; 7, 'P'; 11, 'Q'; 19, 'N'; 15, 'O'; 6, 'G';}; 
    maxDeviationEvents = NaN(length(eventsToCheck), 1);
    for iEvent = 1 : length(eventsToCheck)
        currentEvent = eventsToCheck(iEvent,:);
        currentOEtimestamps = events.(sprintf('evt%d',currentEvent{1})).TS; 
        currentMPCtimestamps = mpcParsedMatch(1).(currentEvent{2});
        if length(currentOEtimestamps) == length(currentMPCtimestamps)
            maxDeviation = max(abs(diff(currentOEtimestamps) - diff(currentMPCtimestamps)));
            maxDeviationEvents(iEvent) = maxDeviation;
            if maxDeviation < maxDeviationSet
                % Events match! 
            else
                fprintf('oe evt %d ts NOT match with mpc %s evt at max deviation %0.2fms %s \n',currentEvent{1},currentEvent{2},maxDeviation*1000, events.(sprintf('evt%d',currentEvent{1})).type)
            end
    
        elseif numel(currentOEtimestamps) > numel(currentMPCtimestamps)                                 % There are extra oephys events.    
            nOff = numel(currentOEtimestamps) - numel(currentMPCtimestamps);
            if nOff > 1  
                fprintf('oe evt %d ts DO NOT match with mpc %s evt %s \n',currentEvent{1},currentEvent{2}, events.(sprintf('evt%d',currentEvent{1})).type)
            end
            minNumber = min([numel(currentOEtimestamps) numel(currentMPCtimestamps)]);
                maxDeviation = abs(diff(currentOEtimestamps(1:minNumber)) - diff(currentMPCtimestamps(1:minNumber)));
                offIndex = find(maxDeviation > maxDeviationSet,1);
                currentOEtimestamps(offIndex +1 ) = [];
                if length(currentOEtimestamps) == length(currentMPCtimestamps)
                    maxDeviation = max(abs(diff(currentOEtimestamps) - diff(currentMPCtimestamps)));
                    maxDeviationEvents(iEvent) = maxDeviation;
                    fprintf('oe evt %d ts fixed with mpc %s evt %s \n',currentEvent{1},currentEvent{2}, events.(sprintf('evt%d',currentEvent{1})).type)
                end
            
        elseif numel(currentOEtimestamps) < numel(currentMPCtimestamps)                             % Oephys is missing events.
            fprintf('oe evt %d ts DO NOT match with mpc %s evt %s \n', currentEvent{1},currentEvent{2}, events.(sprintf('evt%d',currentEvent{1})).type)
            minNumber = min([numel(currentOEtimestamps) numel(currentMPCtimestamps)]);
            maxDeviation = abs(diff(currentOEtimestamps(1:minNumber))-diff(currentMPCtimestamps(1:minNumber)));
            offIndex = find(maxDeviation>maxDeviationSet,1);
            offTimestamps = currentMPCtimestamps(offIndex+1) + (currentOEtimestamps(1) - currentMPCtimestamps(1));
            currentOEtimestamps = sort([currentOEtimestamps; offTimestamps]);
            if length(currentOEtimestamps) == length(currentMPCtimestamps)
                maxDeviation = max(abs(diff(currentOEtimestamps)-  diff(currentMPCtimestamps)));
                maxDeviationEvents(iEvent) = maxDeviation;
                fprintf('oe evt %d ts fixed with mpc %s evt %s \n', currentEvent{1}, currentEvent{2}, events.(sprintf('evt%d',currentEvent{1})).type)
            end
        end
    end
    
    if all(maxDeviationEvents < maxDeviationSet)
        fprintf('all events match with max deviation %0.2fms \n', max(maxDeviationEvents)*1000)
    end
    
    
    

