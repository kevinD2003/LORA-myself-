function layout = senloraPaperPointFrameLayout(c)
%SENLORAPAPERPOINTFRAMELAYOUT Paper Point synchronization, user payload PHY.
m = c.samplesPerSymbol;
if c.bootstrapPilotCount~=8 || mod(m,4)~=0
    error('EXP5Paper:Layout','Requires eight upchirps and quarter-symbol sync.');
end
% Paper Eq.(19): choose one fixed worst-case spacing for the user no-LDRO
% PHY. Three data chirps are not admissible at the Case2 Doppler rate.
% This is an adapted interval, not the final-paper Table 2 n_int=3 profile.
after = (1:c.payloadSymbolCount).';
n = 10+c.payloadSymbolCount+numel(after);
kind = strings(n,1);
kind(1:8) = "bootstrap";
kind(9:10) = "downchirp";
dataIndex = nan(n,1);
dataRows = zeros(c.payloadSymbolCount,1);
midRows = zeros(numel(after),1);
row = 10;
pilot = 0;
for data = 1:c.payloadSymbolCount
    row = row+1;
    kind(row) = "data";
    dataIndex(row) = data;
    dataRows(data) = row;
    if any(after==data)
        row = row+1;
        pilot = pilot+1;
        kind(row) = "midamble";
        midRows(pilot) = row;
    end
end
startSample = (0:n-1).'*m;
startSample(11:end) = startSample(11:end)+m/4;
start = startSample/c.sampleRateHz;
layout = struct('kind',kind,'dataIndex',dataIndex, ...
    'bootstrapRows',(1:8).','downchirpRows',[9;10], ...
    'dataRows',dataRows,'midambleRows',midRows,'midambleAfterDataIndex',after, ...
    'midambleSpacingDataSymbols',1, ...
    'physicalStartSample',startSample,'physicalStartTimeSec',start, ...
    'physicalCenterTimeSec',start+c.symbolDurationSec/2, ...
    'dataStartTimeSec',start(dataRows),'physicalSymbolCount',n, ...
    'quarterSyncStartSample',10*m,'quarterSyncSamples',m/4, ...
    'totalSamples',n*m+m/4,'frameDurationSec',(n+0.25)*c.symbolDurationSec, ...
    'timelineMode','paper-point-native-nint1-two-down-quarter-sync-terminal-pilot');
end
