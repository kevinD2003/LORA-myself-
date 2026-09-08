function anchor=v4TrackAPointAnchor(packet,config)
%V4TRACKAPOINTANCHOR Timestamp the last full downchirp integer estimate.
s=packet.schedule;row=s.pointDownRow;first=s.startSample(row)+1;
samples=packet.rx(first:first+s.sampleCount(row)-1);
estimate=v4PaperNativePointEstimate(samples,config);
anchor=struct('cfoBins',estimate.offsetBins, ...
    'measurementTimeSec',s.centerTimeOffsetSec(row), ...
    'availableAtSec',(s.startSample(row)+s.sampleCount(row))/config.sampleRateHz, ...
    'uncertaintyBins',0.5,'resolution','integer-fft-bin','physicalRow',row);
end
