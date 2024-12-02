function  dates = convertDateStr(dates,conv_type)
% '2019-08-01' <-> '07/31/19'
%regexp(dates,'\d{2}/\d{2}/\d{2}','once')
if all(cellfun(@(x) ~isempty(x), regexp(dates,'\d{2}/\d{2}/\d{2}','once'))) && strcmp(conv_type,'data_date')
    t = datetime(dates,'InputFormat','MM/dd/yy'); %'yyyy-MM-dd'
    dates = datestr(t,'yyyy-mm-dd');
    dates = cellstr(dates);    
elseif all(cellfun(@(x) ~isempty(x),regexp(dates,'\d{4}-\d{2}-\d{2}','once'))) && strcmp(conv_type,'file_date') %file_date
    t = datetime(dates,'InputFormat','yyyy-MM-dd');
    dates = datestr(t,'mm/dd/yy');
    dates = cellstr(dates);    
else
    disp('Date dormat is not consistent or not dates')
end

