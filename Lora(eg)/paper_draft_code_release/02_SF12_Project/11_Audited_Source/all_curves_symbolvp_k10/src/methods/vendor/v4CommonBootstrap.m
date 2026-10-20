function bootstrap=v4CommonBootstrap(rxPilots,config,options)
%V4COMMONBOOTSTRAP Project-aligned eight-upchirp Huang power-combined eta search.
arguments
    rxPilots (:,:) double
    config (1,1) struct
    options.SearchStepBins (1,1) double {mustBePositive}=0.1
end
pilotCount=config.bootstrapPilotCount;m=config.samplesPerSymbol;
if size(rxPilots,1)~=pilotCount||size(rxPilots,2)~=m,error('V4:BootstrapShape','Exactly eight complete upchirps are required.');end
step=options.SearchStepBins;if step>1,error('V4:BootstrapStep','Eta step must not exceed one bin.');end
n=0:m-1;down=conj(v4ModulateSymbol(0,config));eta=(0:step:(1-step/2)).';combined=zeros(numel(eta),m);
for e=1:numel(eta)
    rotation=exp(1i*2*pi*eta(e)*n/m);
    for k=1:pilotCount,z=fft(rxPilots(k,:).*rotation.*down)/sqrt(m);combined(e,:)=combined(e,:)+abs(z).^2;end
end
[peakPerEta,binPerEta]=max(combined,[],2);[peakMetric,best]=max(peakPerEta);integer=binPerEta(best)-1;if integer>=m/2,integer=integer-m;end
epsilon=integer-eta(best);known=zeros(pilotCount,1);joint=v4BootstrapJointPhaseEstimate(rxPilots,known,config,epsilon);
cfoBins=repmat(epsilon,pilotCount,1);phase=zeros(pilotCount,1);ratio=zeros(pilotCount,1);noiseEnergy=zeros(pilotCount,m-1);
for k=1:pilotCount
    tone=rxPilots(k,:).*down.*exp(-1i*2*pi*epsilon*n/m);phase(k)=angle(mean(tone));z=fft(tone)/sqrt(m);amplitude=abs(z);[top,index]=max(amplitude);background=true(1,m);background(max(1,index-1):min(m,index+1))=false;ratio(k)=top/max(median(amplitude(background)),eps);noiseEnergy(k,:)=abs(z(2:end)).^2;
end
noisePower=max(mean(noiseEnergy,'all'),eps);
bootstrap=struct('coarseCfoBins',integer,'cfoBins',cfoBins,'phaseRad',phase, ...
    'rateBinsPerSec',joint.rateBinsPerSec,'jointRateBinsPerSec',joint.rateBinsPerSec, ...
    'joint',joint,'etaHatBins',eta(best),'epsilonHatBins',epsilon, ...
    'integerCfoBin',integer,'etaCandidates',eta,'peakPerEta',peakPerEta, ...
    'peakBinPerEta',binPerEta-1,'peakMetric',peakMetric,'peakRatio',ratio, ...
    'combinedPower',combined,'aggregatePower',combined(best,:),'noisePower',noisePower, ...
    'source','satelliteFig3HuangPrecCpBootstrapEstimate project-aligned', ...
    'usesPayloadTruth',false,'usesOrbitTruth',false);
end
