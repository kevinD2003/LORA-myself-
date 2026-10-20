function report=runChannelChecks()
%RUNCHANNELCHECKS Statistical and waveform checks for the registered channel.
oldPath=path;restore=onCleanup(@()path(oldPath));nk10Setup();profile=nk10Profile();
[a,da]=nk10DrawTaps(4080000000,200000);[b,db]=nk10DrawTaps(4080000000,200000);
assert(isequal(a,b)&&isequal(da,db),'Nk10:Determinism','Same seed must reproduce taps.');
meanTap=mean(a,1);scatter=a;scatter(:,1)=scatter(:,1)-meanTap(1);
estimatedLosPower=abs(meanTap(1))^2;
estimatedDiffusePower=mean(sum(abs(scatter).^2,2));
estimatedK=estimatedLosPower/estimatedDiffusePower;
estimatedTotal=mean(sum(abs(a).^2,2));
assert(abs(estimatedTotal-1)<.01&&abs(10*log10(estimatedK)-10)<.08, ...
    'Nk10:Statistics','K or total power check failed.');
assert(abs(angle(meanTap(1))-pi/4)<.01,'Nk10:ReferencePhase','LOS phase must follow public code.');
impulse=zeros(2,16);impulse(1,1)=1;
observed=nk10ApplyChannel(impulse,a(1,:),da);
serial=reshape(observed.',[],1);
assert(max(abs(serial(1:5)-a(1,:).'))<1e-12&&nnz(abs(serial)>0)==5, ...
    'Nk10:CausalChannel','Causal impulse response mismatch.');

noiselessErrors=zeros(2,1);
for sf=[7 12]
    config=nk10Config(sf);seeds=struct('payloadSeed',4081000000+sf*100, ...
        'noiseSeed',4081000001+sf*100,'channelSeed',4081000002+sf*100, ...
        'paperExtraNoiseSeed',4081000003+sf*100);
    pair=nk10GeneratePair(config,0,100,seeds);c=config.parent;
    native=prefecNativeHardDetect(pair.nativeIdeal.rxPhysical(pair.native.observation.layout.dataRows,:),c);
    paper=prefecNativeHardDetect(pair.pilotIdeal.rxPhysical(pair.pilot.observation.layout.dataRows,:),c);
    truth=pair.native.truth.payloadPhysicalBins(:);
    noiselessErrors(1+(sf==12))=nnz(native.detectedPhysicalBins(:)~=truth)+ ...
        nnz(paper.detectedPhysicalBins(:)~=truth);
    assert(pair.channelExperiment.actualKDb==10&& ...
        pair.channelExperiment.ensembleMeanPower==1&&pair.channelExperiment.linkMarginDb==0);
end
assert(all(noiselessErrors==0),'Nk10:Noiseless','Unexpected high-SNR hard-chirp error.');
report=struct('status','PASS','draws',size(a,1),'estimatedTotalPower',estimatedTotal, ...
    'estimatedKDb',10*log10(estimatedK),'estimatedLosPower',estimatedLosPower, ...
    'estimatedDiffusePower',estimatedDiffusePower,'losPhaseRad',angle(meanTap(1)), ...
    'profileId',profile.id,'noiselessErrors',noiselessErrors, ...
    'projectCarrierHz',868e6,'projectOrbitHeightM',550e3,'bandwidthHz',125e3, ...
    'linkMarginDb',0,'perPacketNormalization',false);
disp(jsonencode(report));
end
