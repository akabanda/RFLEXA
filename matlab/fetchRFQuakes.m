% fetchRFQuakes.m

% This script fetches earthquake data for receiver function analysis,
% and additionally fetches poles and zeros data for the selected
% stations and channels. The earthquake data are saved as .SAC files,
% and their filenames are formatted so that they can be easily linked
% to their corresponding poles and zeros data.
%
%--------------------------------------------------------------------------
% Last updated 4/11/2021 by aburky@princeton.edu
%--------------------------------------------------------------------------

clear,clc

% Define the directory where you would like to save the data
% sacDir = '/Users/aburky/IFILES/NETWORKS/II/SACV/00/';
sacDir = '/Users/aburky/IFILES/NETWORKS/AF/SVMA/';
% sacDir = '/Users/aburky/IFILES/NETWORKS/TA/339A/NULL/RFQUAKES_COUNTS/';

% Define the network/station that you would like to fetch data for
% network = 'TA';
% station = '339A';
network = 'AF';
station = 'SVMA';
location = '*';
channel = 'BH*';

% network = 'II';
% station = 'SACV';
% location = '00';
% channel = 'BH*';

% Define desired earthquake parameters
minMag = 5.5;
maxMag = 9.0;
minRad = 30;
maxRad = 95;

ch = irisFetch.Channels('RESPONSE',network,station,location,channel);

timeFormat = 'yyyy-mm-dd HH:MM:SS.FFF';

% Loop over each channel and make the PZ file
for i = 1:length(ch)
    % Get the channel start and end dates
    t1 = ch(i).StartDate;
    t2 = ch(i).EndDate;
    if isempty(t2)
        dtLocal = datetime('now','TimeZone','Local');
        t2 = datestr(datetime(dtLocal,'TimeZone','Z'),...
            'yyyy-mm-dd HH:MM:SS.FFF');
    end
    
    % Fetch 30 minutes of data from the station to get the Pole/Zero
    % information. If the request returns empty, update the time window
    % and try again
    startChan = t1;
    endChan = datetime(t1) + hours(0.5);
    endChan = datestr(endChan,timeFormat);
    looping = 1;
    while looping == 1
        tr = irisFetch.Traces(network,station,location,...
                ch(i).ChannelCode,startChan,endChan,'includePZ');
        if isempty(tr)
            startChan = datetime(startChan) + days(1);
            startChan = datestr(startChan,timeFormat);
            endChan = datetime(startChan) + hours(0.5);
            endChan = datestr(endChan,timeFormat);
        else
            pz(i) = tr.sacpz;
            looping = 0;
        end
    end
    
    % Save the PZ file
    savePZ(ch(i),pz(i),sacDir,'pzindex',i);
    % While we are iterating over the channel, check for earthquakes
    % that meet our search criterion during its operation
    donut = [ch(i).Latitude,ch(i).Longitude,maxRad,minRad];
    ev = irisFetch.Events('MinimumMagnitude',minMag,'MaximumMagnitude',...
            maxMag,'radialcoordinates',donut,'startTime',t1,...
            'endTime',t2);
        
    % Only fetch events that didn't occur within 1 hour of another event
    gevents(1) = ev(end);
    % Assumes that irisFetch gets events from most recent to least recent?
    % Check this:
    % if seconds(datetime(ev(2).PreferredTime) -
    %            datetime(ev(1).PreferredTime)) > 0
    k = 2;
    for j = length(ev):-1:2
        if hours(datetime(ev(j-1).PreferredTime)-...
                 datetime(ev(j).PreferredTime)) > 1
            gevents(k) = ev(j-1);
            k = k + 1;
        end
    end
    ev = gevents;
        
    % Loop over each event, get the trace for the channel, and save
    for j = 1:length(ev)
        % Get start time of event
        ev_start = ev(j).PreferredTime;
        ev_end = datetime(ev_start) + hours(1);
        ev_end = datestr(ev_end,timeFormat);
        % Fetch trace data from the current channel
        tr = irisFetch.Traces(network,station,location,...
                ch(i).ChannelCode,ev_start,ev_end);
        % Save the trace data to a SAC file
        if ~isempty(tr) && length(tr) == 1
            saveSAC(tr,ev_start,sacDir,'event',ev(j),'pz',i);
        end
    end
end

%% Test to work out date time logic

% Options to add:
% - RESP files? (saveRESP function)
% Note:
% Working with the RESP files is a bit hairy, for negligible difference
% in results. For the time being, do everything with PZ files.

% % Loop over each channel and get the RESP file
% for i = 1:length(ch)
%     t1 = ch(i).StartDate;
%     t2 = datetime(t1) + milliseconds(1);
%     formatOut = 'yyyy-mm-dd HH:MM:SS.FFF';
%     t2 = datestr(t2,formatOut);
%     % Fetch the RESP file
%     re = irisFetch.Resp(network,station,location,ch(i).ChannelCode,t1,t2);
%     % Format the RESP filename
%     respFile = sprintf('RESP.%s.%s.%s.%s.%d',network,station,...
%                ch(i).LocationCode,ch(i).ChannelCode,i);
%     % Save the RESP file
%     fID = fopen(respFile,'w');
%     fprintf(fID,re);
%     fclose(fID);
% end