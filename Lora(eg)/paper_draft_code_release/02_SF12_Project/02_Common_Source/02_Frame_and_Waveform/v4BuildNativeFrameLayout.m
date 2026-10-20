function layout=v4BuildNativeFrameLayout(c,includePaperMidambles)
arguments
 c (1,1) struct
 includePaperMidambles (1,1) logical
end
if includePaperMidambles
 layout=v4BuildFrameLayout(c);layout.timelineMode='native-overhead-paper';return
end
n=c.bootstrapPilotCount+c.payloadSymbolCount;kind=strings(n,1);dataIndex=nan(n,1);
bootstrapRows=(1:c.bootstrapPilotCount).';dataRows=(c.bootstrapPilotCount+1:n).';
kind(bootstrapRows)="bootstrap";kind(dataRows)="data";dataIndex(dataRows)=(1:c.payloadSymbolCount).';
start=(0:n-1).'*c.symbolDurationSec;
layout=struct('kind',kind,'dataIndex',dataIndex,'bootstrapRows',bootstrapRows, ...
 'dataRows',dataRows,'midambleRows',zeros(0,1),'midambleAfterDataIndex',zeros(0,1), ...
 'physicalStartTimeSec',start,'physicalCenterTimeSec',start+c.symbolDurationSec/2, ...
 'dataStartTimeSec',start(dataRows),'physicalSymbolCount',n,'timelineMode','native-overhead-short');
end
