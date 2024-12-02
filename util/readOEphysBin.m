function data = readOEphysBin(filename, sRange, dataType)
% Loads OpenEphys Binary continuous, event, or spike data files into Matlab.
% data = readOEphysBin(filename)
% 
% Inputs:
%       filename: path to file
%       sRange: Sample range of data to read, Optional
%               1x2 array - [startSample endSample]
%       dataType: Types of data to read, Optional
%               cell array - varible field depending on file type
% Outputs:
%       data: struct of data with varible field depending on file type and requested data type
%             No data type is converted, it is original data type to avoid redundant conversion and save memory
%             continuous data and spike waveforms need to be converted to be mV unit
%
% Usage example:
% 
%     % return data with defalut return data type
%     data = readOEphysBin('100_CH2.continuous'); 
% 
%     % get only specfic data ranges for continuous data, useful for very long recording
%     data = readOEphysBin('100_CH2.continuous', [1 1000]); % return data of 1-1000 samples
%     data = readOEphysBin('100_CH2.continuous', [1000 Inf]); % return data of 1000-end of samples
% 
%     % get non-default data output
%     data = readOEphysBin('100_CH2.continuous', [1 Inf], {'ts' 'nsamples' 'data' });
% 
%     % to get available data types
%     data = readOEphysBin('100_CH2.continuous', [1 1], {''}); % no actual data read, but will have header, total block size, available data types
%     dataTypes = {data.dblock.Str}; % extract available data type
%     data = readOEphysBin('100_CH2.continuous', [1 Inf], dataTypes([1, 3, 4])); % Select data type to read
%     
%     % raw continuous data to mV
%     contidata = double(data.data) .* data.header.bitVolts;
% 
%     % raw spike data to mV
%     spikedata = (double(data.data)-32768)./ permute(repmat(data.gain/1000,[1 1 40]), [1 3 2]);
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

[~,~,filetype] = fileparts(filename);
if ~any(strcmp(filetype,{'.events','.continuous','.spikes'}))
    error('File extension not recognized. Please use a ''.continuous'', ''.spikes'', or ''.events'' file.');
end

fid = fopen(filename);
fseek(fid,0,'eof');
filesize = ftell(fid);

NUM_HEADER_BYTES = 1024;
fseek(fid,0,'bof');
hdr = fread(fid, NUM_HEADER_BYTES, 'char*1');
info = getHeader(hdr);
if isfield(info.header, 'version')
    version = info.header.version;
else
    version = 0.0;
end
if strcmp(filetype, '.spikes')
    num_channels = info.header.num_channels;
    num_samples = 40; % if non-default spike length used (8+32, 8+64, 16+32, 16+64), this need to be changed
else
    num_channels = '';
    num_samples = '';
end

OE_EvtTypes = { ...
    'timestamps'	'int64'     1; ... % timestamp (to align with timestamps from the continuous records)
    'sampleNum'     'int16'     1; ... % sample position within a buffer
    'eventType'     'uint8'     1; ... % event type (all the events that are saved have type TTL = 3 ; Network Event = 5)
    'nodeId'        'uint8'     1; ... % processor ID (the processor this event originated from)
    'eventId'       'uint8'     1; ... % event ID (code associated with this event, usually 1 or 0)
    'channel'       'uint8'     1; ... % event channel (the channel this event is associated with)
    'recNum'        'uint16'    1; ... % recording number (version 0.2 and higher)
    };

OE_CntTypes = { ...
    'timestamps'    'int64'     1; ... % timestamp (actually a sample number; this can be converted to seconds using the sampleRate variable in the header)
    'nsamples'      'uint16'    1; ... % number (N) indicating the samples per record (always 1024, at least for now)
    'recNum'        'uint16'    1; ... % recording number (version 0.2 and higher)
    'data'          'int16'     1024; ... % samples
    'recordMarker'  'uint8'     10; ... % record marker (0 1 2 3 4 5 6 7 8 255)
    };

OE_SpkTypes = { ...
    'eventType'             'uint8'     1; ... % eventType (always equal to 4, for spike events)
    'timestamps'            'int64'     1; ... % timestamp (to align with timestamps from the continuous records)
    'timestamps_software'	'int64'     1; ... % software timestamp (not currently used)
    'source'                'uint16'    1; ... % sourceID (electrode number)
    'nChannels'             'uint16'    1; ... % number of channels (N)
    'nSamples'              'uint16'    1; ... % number of samples per spike (M)
    'sortedId'              'uint16'    1; ... % sorted id (used by Spike Sorter)
    'electrodeID'           'uint16'    1; ... % electrodeID (unique electrode ID)
    'channel'               'uint16'    1; ... % channel (channel within the electrode that triggered spike acquisition)
    'color'                 'uint8'     3; ... % color codes (for drawing spikes)
    'pcProj'                'float32'   2; ... % principle component projections (x and y)
    'samplingFrequencyHz'	'uint16'    1; ... 
    'data'                  'uint16'    num_channels*num_samples; ... % samples (individual channels are contiguous)
    'gain'                  'float32'   num_channels; ... % gains (actually gain*1000, to increase resolution)
    'threshold'             'uint16'    num_channels; ... % thresholds used for spike extraction
    'recordingNumber'       'uint16'    1; ... % recording number (version 0.2 and higher)
    };

switch filetype
    case '.events'
        dblock = typecon(OE_EvtTypes);
        if version < 0.2, dblock(7) = [];  end
        if version < 0.1, dblock(1).Types = 'uint64'; end
        outTypes = {'timestamps' 'sampleNum' 'eventType' 'nodeId' 'eventId' 'channel'};
    case '.continuous'
        dblock = typecon(OE_CntTypes);
        if version < 0.2, dblock(3) = []; end
        if version < 0.1, dblock(1).Types = 'uint64'; dblock(2).Types = 'int16'; end
        outTypes = {'data' 'timestamps'};
    case '.spikes'
        dblock = typecon(OE_SpkTypes);
        if version < 0.4,  dblock(7:12) = []; dblock(8).Types = 'uint16'; end
        if version == 0.3, dblock = [dblock(1), struct('Repeat',1,'Types','uint32','Str','ts'), dblock(2:end)]; end
        if version < 0.3, dblock(2) = []; end
        if version < 0.2, dblock(9) = []; end
        if version < 0.1, dblock(2).Types = 'uint64'; end
        outTypes = {'sortedId' 'timestamps' 'data'  'gain' 'nSamples'};
end
typeBytes = str2double(regexp({dblock.Types},'\d{1,2}$','match', 'once'))./8;
blockBytes = typeBytes .* [dblock.Repeat];
skipBytes = NUM_HEADER_BYTES;
numBlock = floor((filesize - NUM_HEADER_BYTES)/sum(blockBytes)); % total number of data block
data.totalBlock = numBlock;
data.dblock = dblock;
data.header = info.header;

if nargin > 1 && strcmp(filetype, '.continuous') % if block range is requested, check if end block is bigger than available
    if ~isempty(sRange)
        SAMPLES_PER_RECORD = info.header.blockLength;
        % change sample number to block number
        bRange = [floor((sRange(1)-1)/SAMPLES_PER_RECORD)+1 ceil(sRange(2)/SAMPLES_PER_RECORD)];
        sIdxRange = [sRange(1)-(bRange(1)-1)*SAMPLES_PER_RECORD diff(sRange)+1];
        skipBytes = sum(blockBytes) * (bRange(1) -1) + skipBytes;
        if numBlock >= bRange(1)
            if numBlock - bRange(1) > diff(bRange)
                numBlock = bRange(2) - bRange(1) + 1;
            else
                numBlock = numBlock - bRange(1) + 1;
            end
        else
            error('invalid range');
        end
    end
end
if nargin == 3 && ~isempty(dataType), outTypes = dataType; end

outIdx = find(ismember({dblock.Str},outTypes));
for bIdx = outIdx
    if strcmp(filetype, '.continuous') && strcmp(dblock(bIdx).Str, 'data')
        data.(dblock(bIdx).Str) = segRead(dblock(bIdx).Str,'b');
    else
        data.(dblock(bIdx).Str) = segRead(dblock(bIdx).Str);
    end
end

switch filetype
    case '.spikes'
        if isfield(data,'gain'), data.gain = permute(reshape(data.gain, num_channels, numBlock), [2 1]); end
        if isfield(data,'threshold'), data.gain = permute(reshape(data.threshold, num_channels, numBlock), [2 1]); end
        if isfield(data,'data'), data.data = permute(reshape(data.data, num_samples, num_channels, numBlock), [3 1 2]); end
    case '.continuous'
        if isfield(data,'data') && nargin > 1, if isinf(sIdxRange(2)), sIdxRange(2) = length(data.data); end, data.data = data.data(sIdxRange(1):sIdxRange(2)); end
end
fclose(fid);

function seg = segRead(segName, mf)
    if nargin == 1, mf = 'l'; end
    segNum = find(strcmp({dblock.Str},segName));
    fseek(fid, sum(blockBytes(1:segNum-1))+skipBytes, 'bof'); 
    seg = fread(fid, numBlock*dblock(segNum).Repeat, sprintf('%d*%s=>%s', dblock(segNum).Repeat,dblock(segNum).Types,dblock(segNum).Types), sum(blockBytes) - blockBytes(segNum), mf);
end

function type = typecon(type)
    type = struct('Str', type(:,1), 'Types', type(:,2), 'Repeat',type(:,3)); 
end

end

function info = getHeader(hdr)
    eval(char(hdr'));
    info.header = header;
end

