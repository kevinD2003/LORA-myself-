function [points,configs]=acProjectConditions()
%ACPROJECTCONDITIONS All case SNR and half-orbit positions, frozen globally.
acSetup();base=sf12NoLdroSf11FlowConfig();profiles=mpK10Profiles();
configs=cell(2,1);sfValues=[7 12];
for k=1:2
    c=base;sf=sfValues(k);
    c.physicalSf=sf;c.effectiveDataSf=sf;c.dataAlphabetSize=2^sf;
    c.samplesPerSymbol=2^sf;c.dataBinSpacing=1;
    c.symbolDurationSec=c.samplesPerSymbol/c.sampleRateHz;
    c.fftBinSpacingHz=c.bandwidthHz/c.samplesPerSymbol;
    c.informationBitCount=16*4*sf;
    c.paperMidambleInterval=3;if sf==7,c.paperMidambleInterval=12;end
    c.paperMidambleCount=floor(111/c.paperMidambleInterval);
    c.commonTimelineSymbolCount=120+c.paperMidambleCount;
    c.snrDb=((-15:-6)-3*(sf-7)).';
    c.projectRoot=fileparts(mfilename('fullpath'));
    c.ricianModel='four-delayed-diffuse-taps-K10';
    plan=struct('nativePhysicalSymbolCount',120,'frameDurationSec',120*c.symbolDurationSec, ...
        'driftBlendStartBins',.10,'driftBlendEndBins',.80,'parametersFrozen',true, ...
        'receiverVersion','SenLoRa-V8-symbol-vp-experiment-v1');
    configs{k}=struct('parent',c,'channelProfile',profiles(5), ...
        'initialChannelPhaseRad',0,'receiverPlan',plan);
end
rows=cell(100,1);index=0;
for channel={'AWGN','Rician'}
    name=channel{1};
    for s=1:2
        sf=sfValues(s);grid=configs{s}.parent.snrDb;
        for caseIndex=1:2
            starts=[-366 0];
            for j=1:numel(grid)
                index=index+1;snr=grid(j);
                rows{index}=entry(index,sf,name,'case',caseIndex,starts(caseIndex),snr,snr+10*log10(2^sf));
            end
        end
        times=[-366 -274.5 -183 -91.5 0];esn0=14;
        if strcmp(name,'Rician'),esn0=15;end
        for j=1:numel(times)
            index=index+1;
            rows{index}=entry(index,sf,name,'half',0,times(j),esn0-10*log10(2^sf),esn0);
        end
    end
end
points=vertcat(rows{:});assert(numel(points)==100);
end

function p=entry(index,sf,channel,family,caseIndex,time,snr,esn0)
id=sprintf('p%03d_sf%d_%s_%s%d',index,sf,lower(channel),family,caseIndex);
p=struct('id',id,'index',index,'sf',sf,'channel',channel,'family',family, ...
    'caseIndex',caseIndex,'orbitStartSec',time,'snrDb',snr,'esN0Db',esn0);
end
