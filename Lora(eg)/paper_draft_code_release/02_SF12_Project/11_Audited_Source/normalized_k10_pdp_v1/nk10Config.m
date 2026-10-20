function config=nk10Config(sf)
%NK10CONFIG User project PHY/orbit with the registered normalized K10 PDP.
arguments
    sf (1,1) double {mustBeMember(sf,[7 12])}
end
roots=nk10Setup();c=sf12NoLdroSf11FlowConfig();
c.projectRoot=roots.root;c.physicalSf=sf;c.effectiveDataSf=sf;
c.dataAlphabetSize=2^sf;c.dataBinSpacing=1;c.samplesPerSymbol=2^sf;
c.symbolDurationSec=c.samplesPerSymbol/c.sampleRateHz;
c.fftBinSpacingHz=c.bandwidthHz/c.samplesPerSymbol;
c.informationBitCount=64*sf;c.paperMidambleInterval=3;
if sf==7,c.paperMidambleInterval=12;end
c.paperMidambleCount=floor(111/c.paperMidambleInterval);
c.commonTimelineSymbolCount=120+c.paperMidambleCount;
c.snrDb=((-15:-6)-3*(sf-7)).';c.ricianKDb=10;
c.ricianModel='normalized-K10-zero-and-delayed-diffuse-PDP';
plan=struct('nativePhysicalSymbolCount',120, ...
    'frameDurationSec',120*c.symbolDurationSec, ...
    'driftBlendStartBins',.10,'driftBlendEndBins',.80, ...
    'parametersFrozen',true,'receiverVersion','SenLoRa-V8-symbol-vp-experiment-v1');
config=struct('parent',c,'channelProfile',nk10Profile(), ...
    'initialChannelPhaseRad',0,'receiverPlan',plan);
end

