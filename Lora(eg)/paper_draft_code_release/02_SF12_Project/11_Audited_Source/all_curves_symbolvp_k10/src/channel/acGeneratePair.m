function pair=acGeneratePair(config,startSec,snrDb,channel,seeds)
%ACGENERATEPAIR Paired native and Paper timelines from one payload/channel.
% Each frame is generated on its own physical timeline BEFORE the causal
% serial multipath channel. The shorter native frame never removes rows from
% an already propagated Paper frame. Common preamble/data noise is paired by
% semantic symbol index; inserted Paper midambles have an independent stream.
% This is a new noise cohort and must not be pooled with mpK10 results.
arguments
    config (1,1) struct
    startSec (1,1) double {mustBeFinite}
    snrDb (1,1) double
    channel (1,1) string {mustBeMember(channel,["AWGN","Rician"])}
    seeds (1,1) struct
end
c=config.parent;
assert(~isnan(snrDb)&&snrDb~=-Inf,'Ac:Snr','SNR must be finite or positive infinity.');
assert(c.physicalSf==c.effectiveDataSf&&ismember(c.physicalSf,[7 12])&& ...
    c.dataBinSpacing==1&&c.dataAlphabetSize==c.samplesPerSymbol&& ...
    c.samplesPerSymbol==2^c.physicalSf&&c.bandwidthHz==125e3&& ...
    c.sampleRateHz==125e3&&c.cr==3&&c.hammingBlockCount==16&& ...
    c.payloadSymbolCount==112&&c.bootstrapPilotCount==8&& ...
    c.informationBitCount==4*c.effectiveDataSf*c.hammingBlockCount&& ...
    c.ricianKDb==10,'Ac:Profile','Use the native 125-kHz no-LDRO CR3 K10 profile.');
assert(isfield(config,'channelProfile'),'Ac:MissingProfile','An explicit global channelProfile is required.');
profile=mpK10ValidateProfile(config.channelProfile);
assert(isequal(profile.delayedSamples,[1 2 3 4])&& ...
    isequal(profile.powers,[.25 .25 .25 .25])&&profile.losPhaseRad==0, ...
    'Ac:GlobalProfile','Use fixed four equal-power scatter taps at 8/16/24/32 microseconds, LOS phase zero.');
initialPhase=0;
if isfield(config,'initialChannelPhaseRad'),initialPhase=config.initialChannelPhaseRad;end
assert(isscalar(initialPhase)&&isfinite(initialPhase)&&initialPhase==0, ...
    'Ac:InitialPhase','The initial common phase is fixed at zero.');
requiredSeeds={'payloadSeed','noiseSeed','channelSeed','paperExtraNoiseSeed'};
assert(all(isfield(seeds,requiredSeeds)),'Ac:Seeds','Payload, common noise, channel and extra Paper noise seeds are required.');
for k=1:numel(requiredSeeds)
    value=seeds.(requiredSeeds{k});
    assert(isscalar(value)&&isfinite(value)&&value>=0&&value==fix(value)&&value<=2^32-1, ...
        'Ac:Seeds','Seeds must be integer scalars in [0,2^32-1].');
end
assert(seeds.noiseSeed~=seeds.paperExtraNoiseSeed,'Ac:IndependentNoise','Paper extra noise needs a distinct seed.');
native=v4GenerateNativeFrame(c,startSec,snrDb,seeds,initialPhase,'AWGN',false);
pilot=v4GenerateNativeFrame(c,startSec,snrDb,seeds,initialPhase,'AWGN',true);
assert(native.observation.layout.physicalSymbolCount==120&& ...
    pilot.observation.layout.physicalSymbolCount==120+floor(111/c.paperMidambleInterval), ...
    'Ac:Layout','Unexpected native or Paper physical symbol count.');
assert(isequal(native.truth.payloadPhysicalBins,pilot.truth.payloadPhysicalBins)&& ...
    isequal(native.truth.dataBits,pilot.truth.dataBits),'Ac:Payload','Both frames must share the same native payload.');
nativePhase=prefecPacketOraclePhase(c,native.truth.payloadPhysicalBins, ...
    native.observation.layout,startSec,initialPhase);
pilotPhase=prefecPacketOraclePhase(c,pilot.truth.payloadPhysicalBins, ...
    pilot.observation.layout,startSec,initialPhase);
if channel=="Rician"
    [taps,delays]=mpK10DiffuseTaps(profile,seeds.channelSeed);
else
    taps=1;delays=0;
end
variance=native.observation.noiseVariance;
[nativeNoise,pilotNoise]=pairedNoise(native.observation.layout,pilot.observation.layout, ...
    c.samplesPerSymbol,variance,seeds);
[native,nativeCleanPower]=propagate(native,nativePhase,nativeNoise);
[pilot,pilotCleanPower]=propagate(pilot,pilotPhase,pilotNoise);
purpose='offline-common-Doppler-removal-only-fading-ISI-and-rotated-noise-retained';
pair=struct('native',native,'pilot',pilot, ...
    'nativeIdeal',struct('rxPhysical',native.observation.rxPhysical.*exp(-1i*nativePhase),'purpose',purpose), ...
    'pilotIdeal',struct('rxPhysical',pilot.observation.rxPhysical.*exp(-1i*pilotPhase),'purpose',purpose), ...
    'ledger',seeds);
pair.power=struct('txPower',1,'noiseVariance',variance,'channelPower',sum(abs(taps).^2), ...
    'measuredNativeCleanPower',nativeCleanPower,'measuredPilotCleanPower',pilotCleanPower, ...
    'channelPowerMeaning','realized-sum-tap-energies-not-normalized');
pair.channelExperiment=struct('cohortId','all-curves-native-paper-semantic-noise-v1', ...
    'actualKDb',10,'meanPower',1,'model','packet-constant-independent-proper-CN-delayed-diffuse-taps', ...
    'profileId',profile.id,'profile',profile,'losPower',10/11,'diffusePower',1/11, ...
    'pathDelaysSamples',delays,'pathDelaysSec',delays/c.sampleRateHz, ...
    'scatterPdp',profile.powers,'extraScatterDopplerHz',0, ...
    'commonNarrowDelayDopplerApproximation',true,'losPhaseRad',0, ...
    'perPacketPowerNormalization',false,'noiseVariance',variance, ...
    'referenceK10Matched',true,'isRician',channel=="Rician", ...
    'policy','one-global-PDP-no-per-point-selection','paperSpecifiedDelayOrPdp',false, ...
    'boundary','zero-before-packet-truncate-tail-after-packet-no-per-chirp-wrap', ...
    'noisePairing','same-known-preamble-and-payload-index-independent-extra-Paper-midambles', ...
    'timeline','native-120-symbols-and-Paper-own-midamble-overhead-before-propagation');
if channel=="AWGN"
    pair.channelExperiment.model='AWGN-no-multipath';
    pair.channelExperiment.losPower=1;
    pair.channelExperiment.diffusePower=0;
    pair.channelExperiment.scatterPdp=[];
end
    function [frame,cleanPower]=propagate(frame,phase,noise)
        layout=frame.observation.layout;
        bins=zeros(layout.physicalSymbolCount,1);
        bins(layout.dataRows)=frame.truth.payloadPhysicalBins;
        tx=complex(zeros(layout.physicalSymbolCount,c.samplesPerSymbol));
        for row=1:layout.physicalSymbolCount,tx(row,:)=v4ModulateSymbol(bins(row),c);end
        faded=mpK10ApplyChannel(tx,taps,delays);
        rx=faded.*exp(1i*phase)+noise;
        frame.observation.rxPhysical=rx;
        frame.observation.sampleFingerprint=[sum(abs(rx(:)).^2) sum(real(rx(:))) sum(imag(rx(:)))];
        frame.truth.oraclePhasePhysicalRad=phase;
        frame.truth.oraclePhasePurpose='offline-ideal-evaluation-only-not-actual-receiver-input';
        frame.truth.channelModel=char(channel);
        if channel=="Rician",frame.truth.channelModel='Rician-delayed-diffuse-common-Doppler';end
        frame.truth.channelCoefficient=taps(1);
        frame.truth.channelTaps=taps;
        frame.truth.channelDelaysSamples=delays;
        frame.truth.channelCoefficientPurpose='LOS-only; full channel is channelTaps/channelDelaysSamples';
        cleanPower=mean(abs(faded(:)).^2);
    end
end

function [nativeNoise,pilotNoise]=pairedNoise(nativeLayout,pilotLayout,m,variance,seeds)
nativeNoise=complex(zeros(nativeLayout.physicalSymbolCount,m));
pilotNoise=complex(zeros(pilotLayout.physicalSymbolCount,m));
if variance==0,return;end
stream=RandStream('mt19937ar','Seed',seeds.noiseSeed);
nativeNoise=sqrt(variance/2)*(randn(stream,size(nativeNoise))+1i*randn(stream,size(nativeNoise)));
pilotNoise(pilotLayout.bootstrapRows,:)=nativeNoise(nativeLayout.bootstrapRows,:);
pilotNoise(pilotLayout.dataRows,:)=nativeNoise(nativeLayout.dataRows,:);
extra=RandStream('mt19937ar','Seed',seeds.paperExtraNoiseSeed);
shape=[numel(pilotLayout.midambleRows),m];
pilotNoise(pilotLayout.midambleRows,:)=sqrt(variance/2)*(randn(extra,shape)+1i*randn(extra,shape));
end
