function data = readOEphysKwik(filename, dRange, dataType)
% Loads OpenEphys Kwik continuous, event, or spike data files into Matlab.
% data = readOEphysKwik(filename)
%
% Inputs:
%       filename: path to file
%       dRange: Range of data to read, Optional
%               a single value - single channel for continuous and spike data
%               2x2 array - [startChannel endChannel; startSample endSample] for continuous data
%       dataType: Types of data to read, Optional
%               cell array - varible field depending on file type
% Outputs:
%       data: struct of data with varible field depending on file type and requested data type
%             No data type is converted, it is original data type to avoid redundant conversion and save memory
%             continuous data and spike waveforms need to be converted to be mV unit
%       
% Usage example:
%
%     % Return data with defalut return data type
%     data = readOEphysKwik('experiment1.kwe'); % return all event data
%     data = readOEphysKwik('experiment1.kwx', 2); % return all spike data from channel 2
%     data = readOEphysKwik('experiment1_100.raw.kwd', 1); % return all continuous data of channel 1
% 
%     % Get only specfic data range, useful for very long continuous recording
%     data = readOEphysKwik('experiment1_100.raw.kwd', [1 2; 1 inf]); % return all data in channel 1 and 2
%     data = readOEphysKwik('experiment1_100.raw.kwd', [1 16; 1000 2000]); % return data of sample number from 1000 to 2000 in channel 1-16
% 
%     % get non-default data output
%     data = readOEphysKwik('experiment1_100.raw.kwe', [], {'channel' 'startTime'}); % return only channel and startTime, no channel selection
%     data = readOEphysKwik('experiment1_100.raw.kwd', 1, {'validSamples'}); % return only available sample number without actual data
% 
%     % to get available data types
%     data = readOEphysKwik('experiment1_100.raw.kwd', 1, {''}); % no actual data read, but will have header, available data types
%     dataTypes = {data.dblock.Str}; % extract available data type
%     data = readOEphysKwik('experiment1_100.raw.kwd', 1, dataTypes([1, 3, 4])); % Select data type to read
%     
%     % raw continuous data to mV
%     data = readOEphysKwik('experiment1_100.raw.kwd', 1, {'data' 'bitVolts'});
%     contidata = double(data.data) .* double(data.bitVolts(1));
%
%   See also readOEphys, readSessionXML, readOEphysBin.
%
% Copyright (C) 2016 Open Ephys
% 
% This program is free software: you can redistribute it and/or modify
% it under the terms of the GNU General Public License as published by
% the Free Software Foundation, either version 3 of the License, or
% (at your option) any later version.
% 
% This program is distributed in the hope that it will be useful,
% but WITHOUT ANY WARRANTY; without even the implied warranty of
% MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
% GNU General Public License for more details.
% 
% <http://www.gnu.org/licenses/>.

Kwik_EvtTypes = { ...
    'timestamps'        '/event_types/TTL/events/time_samples'; ...
    'nodeId'            '/event_types/TTL/events/user_data/nodeID'; ...
    'eventId'           '/event_types/TTL/events/user_data/eventID'; ...
    'channel'           '/event_types/TTL/events/user_data/event_channels'; ...
    'ttlRecord'         '/event_types/TTL/events/recording'; ...
    'version'           {'/','kwik_version'}; ...
    'name'              {'/recordings/0','name'}; ...
    'start_time'        {'/recordings/0','start_time'}; ...
    'sampleRate'        {'/recordings/0','sample_rate'}; ...
    'bitDepth'          {'/recordings/0','bit_depth'}; ...
    'startTime'     	'/event_types/Messages/events/time_samples'; ...
    'eventRecord'       '/event_types/Messages/events/recording'; ...
    'messageEvtText'    '/event_types/Messages/events/user_data/Text'; ...
    'messageEvtId'   	'/event_types/Messages/events/user_data/eventID'; ...
    'messageRecord'     '/event_types/Messages/events/user_data/nodeID'; ...
    };

Kwik_SpkTypes = { ...
    'sortedId'          '/channel_groups/%d/recordings'; ...
    'timestamps'        '/channel_groups/%d/time_samples'; ...
    'data'              '/channel_groups/%d/waveforms_filtered'; ...
    };

Kwik_CntTypes_old = { ...
    'version'           {'/','kwik_version'}; ...
    'name'              {'/recordings/0','name'}; ...
    'startTime'         {'/recordings/0','start_time'}; ...
    'startSample'       {'/recordings/0','start_sample'}; ...
    'sampleRate'        {'/recordings/0','sample_rate'}; ...
    'bitDepth'          {'/recordings/0','bit_depth'}; ...
    'bitVolts'          {'/recordings/0/application_data','channel_bit_volts'}; ...
    'isMultiSampleRate' {'/recordings/0/application_data','is_multiSampleRate_data'}; ...
    'chSampleRates'     {'/recordings/0/application_data','channel_sample_rates'}; ...
    'data'              '/recordings/0/data'; ...
    'validSamples'      {'/recordings/0/data','valid_samples'}; ...
    };

% OpenEphys 0.4.1
% Kwik_CntTypes = { ...
%     'version'           {'/','kwik_version'}; ...
%     'name'              {'/recordings/%d','name'}; ...
%     'startTime'         {'/recordings/%d','start_time'}; ...
%     'startSample'       {'/recordings/%d','start_sample'}; ...
%     'sampleRate'        {'/recordings/%d','sample_rate'}; ...
%     'bitDepth'          {'/recordings/%d','bit_depth'}; ...
%     'data'              '/recordings/%d/data'; ...
%     'validSamples'      {'/recordings/%d/data','valid_samples'}; ...
%     
%     'isMultiSampleRate' {'/recordings/%d/application_data','is_multiSampleRate_data'}; ...
%     'bitVolts'          '/recordings/%d/application_data/channel_bit_volts'; ...
%     'chSampleRates'     '/recordings/%d/application_data/channel_sample_rates'; ...
%     'timestamps'        '/recordings/%d/application_data/timestamps'; ...
%     };
Kwik_CntTypes = { ...
    'version'           {'/','kwik_version'}; ...
    'name'              {'','name'}; ...
    'startTime'         {'','start_time'}; ...
    'startSample'       {'','start_sample'}; ...
    'sampleRate'        {'','sample_rate'}; ...
    'bitDepth'          {'','bit_depth'}; ...
    'data'              '/data'; ...
    'validSamples'      {'/data','valid_samples'}; ...
    
    'isMultiSampleRate' {'/application_data','is_multiSampleRate_data'}; ...
    'bitVolts'          '/application_data/channel_bit_volts'; ...
    'chSampleRates'     '/application_data/channel_sample_rates'; ...
    'timestamps'        '/application_data/timestamps'; ...
    };


% check file type
[~, ~, filetype] = fileparts(filename);
if ~any(strcmp(filetype,{'.kwe','.kwd','.kwx','.kwik'}))
    error('File extension not recognized. Please use a ''.kwe'', ''.kwd'', ''.kwx''  or ''.kwik'' file.');
end

% check version
version = h5readatt(filename,'/','kwik_version');
if ~(version == 2)
    error('Only version 2 Kwik is supported');
end


% check range and channel requested / set default output data type
switch filetype
    case '.kwe' % event data
        dataTypePath = Kwik_EvtTypes;
        %outTypes = {'timestamps' 'nodeId' 'eventId' 'channel'};
        outTypes = {'timestamps','eventType','nodeId','eventId','channel','ttlRecord','version','name','start_time','sampleRate','bitDepth','startTime','eventRecord','messageEvtText','messageEvtId','messageRecord'};
        if (nargin > 1) && ~isempty(dRange), warning('event data do not support channel range and data range'); end
        data.dblock = struct('Str',dataTypePath(:,1),'Paths', dataTypePath(:,2));
    case '.kwx' % spike data
%         kwxinfo = h5info(filename);
%         dataTypePath = cell(length(kwxinfo.Groups.Groups)*length(Kwik_SpkTypes),3);
%         for spkCh = 1:length(kwxinfo.Groups.Groups)
%             for typeIdx = 1:length(Kwik_SpkTypes)
%                 dataTypePath{(spkCh-1)*3+typeIdx,1} = Kwik_SpkTypes{typeIdx,1};
%                 dataTypePath{(spkCh-1)*3+typeIdx,2} = sprintf(Kwik_SpkTypes{typeIdx,2},spkCh-1);
%                 dataTypePath{(spkCh-1)*3+typeIdx,3} = spkCh;
%             end
%         end

        if nargin > 1
            if numel(dRange) == 1
                dataTypePath(:,1) = Kwik_SpkTypes(:,1);
                for typeIdx = 1:length(Kwik_SpkTypes)
                    dataTypePath{typeIdx,2} = sprintf(Kwik_SpkTypes{typeIdx,2},dRange-1);
                end
                data.dblock = struct('Str',dataTypePath(:,1),'Paths', dataTypePath(:,2));
            else
                error('spike data do not support channel range and data range, single channel only');
            end
        else
            error('spike data require channel number');
        end
        outTypes = {'timestamps' 'data' 'sortedId'};
    case '.kwd' % continous data
        cntGroup_info = h5info(filename, '/recordings');
          % this do not seem to differentiate old version from new version
          % NEED TO FIX
%         if length(cntGroup_info.Groups(1).Groups.Attributes) == 3
%            dataTypePath = Kwik_CntTypes_old;
%         else
            % check num of data group and make path
            cntGroup = {cntGroup_info.Groups.Name};
            % check number of sample, pick max group
            for groupIdx = 1:length(cntGroup)
                % some kwd file do not have valid_samples
                if ~isempty(cntGroup_info.Groups(groupIdx).Datasets.Attributes)
                    numv = h5readatt(filename, [cntGroup{groupIdx} '/data'], 'valid_samples');
                else % get size of data directly
                    numv = cntGroup_info.Groups(groupIdx).Datasets.Dataspace.Size(2);
                end
                numsample(groupIdx) = double(numv(1));
            end
            [~,maxGrIdx] = max(numsample);
            dataTypePath(:,1) = Kwik_CntTypes(:,1);
            for typeIdx = 1:length(Kwik_CntTypes)
                if ~strcmp('version', Kwik_CntTypes{typeIdx,1})
                    if iscell(Kwik_CntTypes{typeIdx,2})
                        dataTypePath{typeIdx,2}{1} = sprintf('%s%s',cntGroup{maxGrIdx}, Kwik_CntTypes{typeIdx,2}{1});
                        dataTypePath{typeIdx,2}{2} = Kwik_CntTypes{typeIdx,2}{2};
                    else
                        dataTypePath{typeIdx,2} = sprintf('%s%s',cntGroup{maxGrIdx}, Kwik_CntTypes{typeIdx,2});
                    end
                else
                    dataTypePath{typeIdx,2} = Kwik_CntTypes{typeIdx,2};
                end
            end
            % if validSamples attribute is not exist, remove from dataTypePath, then return data size
            if nargin > 2 && ~isempty(dataType)
                if any(strcmp('validSamples', dataType)) && isempty(cntGroup_info.Groups(maxGrIdx).Datasets.Attributes)
                    dataTypePath = dataTypePath(~strcmp('validSamples', dataTypePath(:,1)),:);
                    data.validSamples = repmat(cntGroup_info.Groups(maxGrIdx).Datasets.Dataspace.Size(2),[cntGroup_info.Groups.Datasets.Dataspace.Size(1) 1]);
                end
            end
%         end

        if nargin > 1
            if numel(dRange) == 1
                chRange = [dRange dRange];
                sampleRange = [1 Inf];
            elseif numel(dRange) == 4
                chRange = dRange(1,:);
                sampleRange = dRange(2,:);
            else
                error('continous data require channel number or channel range/sample range');
            end
        else
            error('continous data require channel number or range');
        end
        outTypes = {'data'};
        data.dblock = struct('Str',dataTypePath(:,1),'Paths', dataTypePath(:,2));
end


% set requested output data type
if nargin > 2 && ~isempty(dataType), outTypes = dataType; end

% read data for requested types, range, channels
outIdx = find(ismember(dataTypePath(:,1),outTypes));
for bIdx = 1:length(outIdx)
    if iscell(dataTypePath{outIdx(bIdx),2})
        data.(dataTypePath{outIdx(bIdx),1}) =  h5readatt(filename,dataTypePath{outIdx(bIdx),2}{1},dataTypePath{outIdx(bIdx),2}{2});
    else
        if strcmp(dataTypePath{outIdx(bIdx),1}, 'data') && strcmp(filetype, '.kwd')
            data.(dataTypePath{outIdx(bIdx),1}) =  h5read(filename,dataTypePath{outIdx(bIdx),2}, [chRange(1) sampleRange(1)],[chRange(2)-chRange(1)+1 sampleRange(2)-sampleRange(1)+1])';  % [start channel start sample number],[end channel, end sample number]
        % 6/4/2018 fix for OpenEphys > 0.4.3 bug - kwe do not have proper StartTime, get it from Continous data (first tims stamp)
        % kwe '/event_types/Messages/events/time_samples' have incorrect Ts
%         elseif strcmp(dataTypePath{outIdx(bIdx),1}, 'startTime') && strcmp(filetype, '.kwe')
%             filepath = fileparts(filename);
%             dirFiles = dir([filepath filesep '*.kwd']);
%             data.(dataTypePath{outIdx(bIdx),1}) =  uint64(h5read(fullfile(filepath, dirFiles(1).name),'/recordings/0/application_data/timestamps', [1 1], [1 1]));
        else
            data.(dataTypePath{outIdx(bIdx),1}) =  h5read(filename,dataTypePath{outIdx(bIdx),2});
        end
    end
end

end
