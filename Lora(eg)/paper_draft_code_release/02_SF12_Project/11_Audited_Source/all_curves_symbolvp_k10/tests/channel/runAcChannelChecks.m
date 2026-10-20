function report=runAcChannelChecks()
%RUNACCHANNELCHECKS Paired native/Paper frame, fixed-power channel checks.
root=fileparts(fileparts(fileparts(mfilename('fullpath'))));
oldPath=path;restore=onCleanup(@()path(oldPath));
prior=fullfile(fileparts(root),'prefec_revision');addpath(prior);prefecSetup();
addpath(genpath(fullfile(root,'src','channel')));
profiles=mpK10Profiles();profile=profiles(5);
checks=strings(0,1);
seeds=struct('payloadSeed',181001,'noiseSeed',181002,'channelSeed',181003, ...
    'paperExtraNoiseSeed',181004);
assert(isequal(profile.delayedSamples,[1 2 3 4])&&isequal(profile.powers,ones(1,4)/4),'AcTest:Profile','Fixed profile5 mismatch.');
[tapDraws,delays]=mpK10DiffuseTaps(profile,seeds.channelSeed,200000);
assert(isequal(delays,[0 1 2 3 4])&&all(tapDraws(:,1)==sqrt(10/11)),'AcTest:Taps','Delays or LOS tap mismatch.');
assert(abs(mean(sum(abs(tapDraws).^2,2))-1)<.002,'AcTest:MeanPower','Channel ensemble power mismatch.');
assert(all(abs(mean(abs(tapDraws(:,2:end)).^2,1)-1/44)<.0004),'AcTest:TapPower','Scatter power mismatch.');
assert(abs(var(sum(abs(tapDraws).^2,2),1)/(1/(4*121))-1)<.035,'AcTest:TapVariance','Unnormalized tap energy variance mismatch.');
assert(abs(mean(tapDraws(:,2:end).^2,'all'))<.0003,'AcTest:Proper','Scatter proper-CN mismatch.');
pass('200000 channel draws: LOS10/11, four proper-CN taps1/44 each, ensemble power1, variable realized energy without normalization');
x=[1 2 3;4 5 6];h=[.5 1i -.25];d=[0 1 4];
expected=conv(reshape(x.',[],1),[.5 1i 0 0 -.25]);
actual=mpK10ApplyChannel(x,h,d);
assert(isequal(reshape(actual.',[],1),expected(1:numel(x))),'AcTest:Conv','Independent conv mismatch.');
assert(isequal(mpK10ApplyChannel([0 0 1;2 0 0],1,1),[0 0 0;1 2 0]));
pass('Causal serial convolution matches independent conv, crosses symbol boundaries, zero-pads start and truncates tail');
maxNoiseError=0;maxIdealError=0;
for sf=[7 12]
    c=sf12NoLdroSf11FlowConfig();
    if sf==7
        c.physicalSf=7;c.effectiveDataSf=7;c.samplesPerSymbol=128;
        c.dataAlphabetSize=128;c.dataBinSpacing=1;
        c.symbolDurationSec=128/c.sampleRateHz;c.fftBinSpacingHz=c.bandwidthHz/128;
        c.informationBitCount=16*7*4;c.paperMidambleInterval=12;
        c.paperMidambleCount=floor(111/12);c.commonTimelineSymbolCount=120+c.paperMidambleCount;
    end
    config=struct('parent',c,'initialChannelPhaseRad',0,'channelProfile',profile);
    for startSec=[-366 0]
        snrDb=-9;
        awgn=acGeneratePair(config,startSec,snrDb,"AWGN",seeds);
        frozen=v4GenerateNativeFrame(c,startSec,snrDb,seeds,0,'AWGN',false);
        assert(isequaln(awgn.native.observation,frozen.observation),'AcTest:FrozenAwgn','AWGN native observations must exactly match frozen generation.');
        assert(isequal(awgn.native.truth.payloadPhysicalBins,frozen.truth.payloadPhysicalBins));
        assert(awgn.native.observation.layout.physicalSymbolCount==120);
        assert(awgn.pilot.observation.layout.physicalSymbolCount==120+c.paperMidambleCount);
        assert(isempty(awgn.native.observation.layout.midambleRows));
        assert(isequal(awgn.native.truth.dataBits,awgn.pilot.truth.dataBits));
        assert(isequal(awgn.native.truth.payloadPhysicalBins,awgn.pilot.truth.payloadPhysicalBins));
        assert(abs(awgn.native.nextFrameStartTimeSec-(startSec+120*c.symbolDurationSec))<1e-12);
        assert(abs(awgn.pilot.nextFrameStartTimeSec-(startSec+(120+c.paperMidambleCount)*c.symbolDurationSec))<1e-12);
        assert(awgn.native.truth.firstSamplePhaseRad==0&&awgn.pilot.truth.firstSamplePhaseRad==0);
        independentOrbitCheck(c,startSec,awgn.native);
        independentOrbitCheck(c,startSec,awgn.pilot);
        clean=acGeneratePair(config,startSec,Inf,"AWGN",seeds);
        verifyPairNoise(awgn,clean,c,seeds);
        for channel=["AWGN","Rician"]
            pair=acGeneratePair(config,startSec,snrDb,channel,seeds);
            noiseless=acGeneratePair(config,startSec,Inf,channel,seeds);
            assert(isequal(pair.ledger,seeds));
            assert(isequal(pair.native.truth.channelTaps,pair.pilot.truth.channelTaps));
            assert(isequal(pair.native.truth.payloadPhysicalBins,awgn.native.truth.payloadPhysicalBins));
            assert(isequal(pair.native.truth.dataBits,awgn.native.truth.dataBits));
            assert(pair.power.noiseVariance==10^(-snrDb/10)&&pair.power.txPower==1);
            assert(~pair.channelExperiment.perPacketPowerNormalization);
            assert(strcmp(pair.channelExperiment.cohortId,'all-curves-native-paper-semantic-noise-v1'));
            if channel=="Rician"
                [expectedTaps,expectedDelays]=mpK10DiffuseTaps(profile,seeds.channelSeed);
                assert(isequal(pair.native.truth.channelTaps,expectedTaps));
                assert(isequal(pair.native.truth.channelDelaysSamples,expectedDelays));
                assert(pair.power.channelPower==sum(abs(expectedTaps).^2));
                assert(max(abs(pair.channelExperiment.pathDelaysSec-[0 8 16 24 32]*1e-6))<1e-18);
            else
                assert(isequal(pair.native.truth.channelTaps,1)&&pair.power.channelPower==1);
            end
            verifyPairNoise(pair,noiseless,c,seeds);
            for frameName=["native","pilot"]
                f=pair.(frameName);f0=noiseless.(frameName);
                idealName=frameName+"Ideal";phase=f.truth.oraclePhasePhysicalRad;
                assert(isequal(sort(fieldnames(f.observation)), ...
                    sort({'rxPhysical';'layout';'noiseVariance';'sampleFingerprint'})));
                assert(isequal(pair.(idealName).rxPhysical,f.observation.rxPhysical.*exp(-1i*phase)));
                tx=physicalTx(c,f0);
                expectedClean=mpK10ApplyChannel(tx,f0.truth.channelTaps,f0.truth.channelDelaysSamples);
                idealError=max(abs(noiseless.(idealName).rxPhysical(:)-expectedClean(:)));
                maxIdealError=max(maxIdealError,idealError);
                assert(idealError<1e-12);
                assert(isequal(f.truth.oraclePhasePhysicalRad,f0.truth.oraclePhasePhysicalRad));
            end
            nativeKeep=[noiseless.pilot.observation.layout.bootstrapRows;noiseless.pilot.observation.layout.dataRows];
            extracted=noiseless.pilot.observation.rxPhysical(nativeKeep,:);
            assert(max(abs(extracted(:)-noiseless.native.observation.rxPhysical(:)))>1e-7, ...
                'AcTest:OwnTimeline','Removing propagated Paper rows must not reproduce native reception.');
        end
    end
end
pass('SF7/SF12 at approach/zenith: AWGN native observations exactly match independent frozen generation, with native120 and Paper129/157 own physical timelines');
pass('Identical native CR3/16-block/112-chirp payload/data bits and one fixed K10 realization across both frame layouts');
pass('Known preamble and each data-index share exact seeded complex noise; extra Paper midambles use their independent seeded stream, fixed average-SNR variance');
pass('Independent orbital formula verifies 550-km orbit, inclination15deg, Earth rotation, max elevation56deg and exact sample Doppler on each own timeline');
pass('Receiver observations contain no truth; both offline ideal arrays remove only common phase and retain fading, ISI and rotated noise');
report=struct('status','PASS','checks',checks,'statisticalChannelDraws',200000, ...
    'maxNoiseReconstructionError',maxNoiseError,'maxNoiselessIdealError',maxIdealError, ...
    'ricianKDb',10,'delaysMicroseconds',[0 8 16 24 32], ...
    'losPower',10/11,'diffuseTapPowers',ones(1,4)/44, ...
    'nativePhysicalRows',120,'paperPhysicalRowsSf7',129,'paperPhysicalRowsSf12',157, ...
    'cohortId','all-curves-native-paper-semantic-noise-v1');
file=fullfile(root,'tests','channel','CHANNEL_CHECKS.json');
fid=fopen(file,'w');assert(fid>=0);fileCleanup=onCleanup(@()fclose(fid));
fprintf(fid,'%s',jsonencode(report,'PrettyPrint',true));disp(report);
    function pass(message),checks(end+1,1)=message;disp("PASS: "+message);end
    function verifyPairNoise(pair,clean,c,seeds)
        variance=pair.power.noiseVariance;
        stream=RandStream('mt19937ar','Seed',seeds.noiseSeed);
        shape=[120 c.samplesPerSymbol];
        expected=sqrt(variance/2)*(randn(stream,shape)+1i*randn(stream,shape));
        nativeNoise=pair.native.observation.rxPhysical-clean.native.observation.rxPhysical;
        pilotNoise=pair.pilot.observation.rxPhysical-clean.pilot.observation.rxPhysical;
        nl=pair.native.observation.layout;pl=pair.pilot.observation.layout;
        e=max(abs(nativeNoise(:)-expected(:)));maxNoiseError=max(maxNoiseError,e);assert(e<1e-12);
        e=max(abs(pilotNoise(pl.bootstrapRows,:)-nativeNoise(nl.bootstrapRows,:)),[],'all');assert(e<1e-12);
        e=max(abs(pilotNoise(pl.dataRows,:)-nativeNoise(nl.dataRows,:)),[],'all');assert(e<1e-12);
        stream=RandStream('mt19937ar','Seed',seeds.paperExtraNoiseSeed);
        shape=[numel(pl.midambleRows),c.samplesPerSymbol];
        expected=sqrt(variance/2)*(randn(stream,shape)+1i*randn(stream,shape));
        e=max(abs(pilotNoise(pl.midambleRows,:)-expected),[],'all');assert(e<1e-12);
    end
end

function tx=physicalTx(c,frame)
layout=frame.observation.layout;bins=zeros(layout.physicalSymbolCount,1);
bins(layout.dataRows)=frame.truth.payloadPhysicalBins;
tx=complex(zeros(layout.physicalSymbolCount,c.samplesPerSymbol));
for row=1:layout.physicalSymbolCount,tx(row,:)=v4ModulateSymbol(bins(row),c);end
end

function independentOrbitCheck(c,startSec,frame)
% Scalar formula independent of v4Trajectory, evaluated at each chirp centre.
rs=6371e3+550e3;omega=sqrt(9.8*(6371e3)^2/rs^3)-7.292e-5*cosd(15);
gamma0=acos((6371e3/rs)*cosd(56))-deg2rad(56);
layout=frame.observation.layout;
sampleCentre=floor(c.samplesPerSymbol/2);
t=startSec+((layout.dataRows-1)*c.samplesPerSymbol+sampleCentre)/c.sampleRateHz;
angle=omega*t;cosGamma=cos(gamma0)*cos(angle);
range=sqrt(rs^2+(6371e3)^2-2*rs*6371e3*cosGamma);
velocity=6371e3*rs*cos(gamma0)*omega*sin(angle)./range;
frequency=zeros(numel(layout.dataRows),1);
for k=1:numel(frequency)
    f=v4SymbolFrequency(frame.truth.payloadPhysicalBins(k),c);
    frequency(k)=f(sampleCentre+1);
end
expected=-(868e6+frequency).*velocity/3e8/c.fftBinSpacingHz;
assert(max(abs(frame.truth.dataCfoBins-expected))<1e-10);
end
