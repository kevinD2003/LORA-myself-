function report=acRunMethodTests(outputPath)
%ACRUNMETHODTESTS Cross-SF frozen-source equivalence and receiver boundaries.
arguments
    outputPath = ''
end
methodRoot=fullfile(fileparts(fileparts(fileparts(mfilename('fullpath')))), ...
    'src','methods');
addpath(methodRoot,'-begin');
identity=acMethodSources();
oldPath=path; cleanup=onCleanup(@()path(oldPath));
report=struct('passed',false,'sourceIdentity',identity,'fixtures',[]);
records=cell(2,1);
for index=1:2
    sf=[7 12]; sf=sf(index);
    [pair,config]=localFixture(sf);
    timer=tic;
    actual=acDecodeMethods(pair,config);
    decodeSeconds=toc(timer);
    % Use original source paths, including the SF12 original setup hierarchy.
    localOriginalPaths(sf);
    c=config.parent;
    native=pair.native.observation;
    p=v4LoadMethodAlignedR3ParametersV1();
    common=v4CommonBootstrap(native.rxPhysical(1:8,:),c,SearchStepBins=p.searchStepBins);
    expected=senloraSymmetricV8SymbolVpDecode(native,common, ...
        struct('parent',c),config.receiverPlan,SymbolVpHistoryLength=8);
    precInput=native; precInput.noiseVariance=common.noisePower;
    expectedPrec=v4HuangPrecUnifiedDecodeV9(precInput,c);
    assert(isequal(actual.VP.detectedPhysicalBins,expected.detectedPhysicalBins));
    assert(isequal(actual.VP.firstPassDetectedPhysicalBins,expected.firstPassDetectedPhysicalBins));
    assert(isequal(actual.VP.estimatedCfoBins,expected.estimatedCfoBins));
    assert(isequal(actual.VP.estimatedRateBinsPerSec,expected.estimatedRateBinsPerSec));
    assert(isequal(actual.PREC.detectedPhysicalBins,expectedPrec.detectedPhysicalBins));
    % Generator metadata and truth may be replaced without affecting decoding.
    acMethodSources();
    poisoned=pair;
    poisoned.native.truth=struct('poison',true);
    poisoned.pilot.truth=struct('poison',true);
    poisoned.native.observation.noiseVariance=1e200;
    poisoned.pilot.observation.noiseVariance=1e-200;
    poisoned.ledger=struct('snrDb',-999,'channel','POISON','caseIndex',99);
    repeated=acDecodeMethods(poisoned,config);
    for name={'VP','PREC','Paper'}
        key=name{1};
        assert(isequal(actual.(key).detectedPhysicalBins,repeated.(key).detectedPhysicalBins));
        assert(isequal(actual.(key).estimatedCfoBins,repeated.(key).estimatedCfoBins));
    end
    assert(actual.noisePowerEstimate==repeated.noisePowerEstimate);
    % A received future block/pilot cannot change already emitted chirps.
    altered=pair; cutoffData=84;
    nativeFirst=pair.native.observation.layout.dataRows(cutoffData+1);
    paperFirst=pair.pilot.observation.layout.dataRows(cutoffData)+1;
    altered.native.observation.rxPhysical(nativeFirst:end,:)= ...
        -conj(altered.native.observation.rxPhysical(nativeFirst:end,:));
    altered.pilot.observation.rxPhysical(paperFirst:end,:)= ...
        -conj(altered.pilot.observation.rxPhysical(paperFirst:end,:));
    future=acDecodeMethods(altered,config);
    for name={'VP','PREC','Paper'}
        key=name{1};
        assert(isequal(actual.(key).detectedPhysicalBins(1:cutoffData), ...
            future.(key).detectedPhysicalBins(1:cutoffData)));
        assert(isequal(actual.(key).estimatedCfoBins(1:cutoffData), ...
            future.(key).estimatedCfoBins(1:cutoffData)));
    end
    observations=actual.VP.symbolObservations;
    used=isfinite(observations.firstUsedAtPhysicalRow);
    assert(all(observations.firstUsedAtPhysicalRow(used)>=observations.availablePhysicalRow(used)));
    assert(all(observations.availablePhysicalRow> ...
        pair.native.observation.layout.dataRows(observations.symbolIndex)));
    assert(size(unique(observations.sampleFingerprint,'rows'),1)>100);
    assert(numel(unique(round(observations.residualCfoBins*1e8)))>1);
    assert(all(actual.VP.fitLog.historyCount<=8));
    assert(any(actual.VP.fitLog.historyCount>0));
    if sf==7
        % Force a real PREC-only metadata failure without replacing code.
        broken=config; broken.parent.methodNames={};
        isolated=acDecodeMethods(pair,broken);
        assert(isolated.failures.PREC && isempty(isolated.PREC));
        assert(~isolated.failures.VP && ~isolated.failures.Paper);
        assert(strlength(isolated.messages.PREC)>0);
        assert(isequal(isolated.VP.detectedPhysicalBins,actual.VP.detectedPhysicalBins));
        assert(isequal(isolated.Paper.detectedPhysicalBins,actual.Paper.detectedPhysicalBins));
    end
    records{index}=struct('sf',sf,'originalSourceExact',true, ...
        'firstPassExact',true,'precExact',true,'truthAndNoiseMetadataInvariant',true, ...
        'futureSamplesCausal',true,'symbolMeasurementsDistinct',true, ...
        'independentFailureIsolationTested',sf==7, ...
        'acceptedSymbols',actual.VP.acceptedVirtualPilots, ...
        'usedSymbols',actual.VP.usedVirtualPilots, ...
        'rateUpdates',sum(actual.VP.fitLog.rateUpdated), ...
        'maxHistory',max(actual.VP.fitLog.historyCount), ...
        'noisePowerEstimate',actual.noisePowerEstimate,'decodeSeconds',decodeSeconds);
    fprintf('METHOD_FIXTURE_PASS sf=%d seconds=%.3f accepted=%d used=%d rateUpdates=%d\n', ...
        sf,decodeSeconds,records{index}.acceptedSymbols,records{index}.usedSymbols,records{index}.rateUpdates);
end
report.fixtures=vertcat(records{:}); report.independentFailureIsolationPassed=true;
report.passed=true;
if strlength(string(outputPath))>0
    fid=fopen(outputPath,'w'); assert(fid>=0); closer=onCleanup(@()fclose(fid));
    fprintf(fid,'%s\n',jsonencode(report,PrettyPrint=true));
end
end

function [pair,config]=localFixture(sf)
c=struct('physicalSf',sf,'effectiveDataSf',sf,'dataAlphabetSize',2^sf, ...
    'dataBinSpacing',1,'bandwidthHz',125e3,'sampleRateHz',125e3, ...
    'samplesPerSymbol',2^sf,'symbolDurationSec',2^sf/125e3, ...
    'fftBinSpacingHz',125e3/2^sf,'carrierFrequencyHz',868e6, ...
    'cr',3,'hammingCodewordLength',7,'hammingBlockCount',16, ...
    'payloadSymbolCount',112,'informationBitCount',16*sf*4, ...
    'bootstrapPilotCount',8,'virtualPilotHistoryLength',8, ...
    'maxSenLoRaIterations',5,'noMidambleFrameSymbolCount',120, ...
    'methodNames',{{'PREC';'VP';'Paper'}});
if sf==7, c.paperMidambleInterval=12; else, c.paperMidambleInterval=3; end
c.paperMidambleCount=floor(111/c.paperMidambleInterval);
c.commonTimelineSymbolCount=120+c.paperMidambleCount;
plan=struct('nativePhysicalSymbolCount',120,'frameDurationSec',120*c.symbolDurationSec, ...
    'driftBlendStartBins',.10,'driftBlendEndBins',.80,'parametersFrozen',true);
config=struct('parent',c,'receiverPlan',plan);
payload=v4GeneratePayload(c,80000+sf);
native=v4BuildNativeFrameLayout(c,false); paper=v4BuildNativeFrameLayout(c,true);
pair=struct('native',struct('observation',localSamples(native,payload,c,100+sf)), ...
    'pilot',struct('observation',localSamples(paper,payload,c,200+sf)));
end

function observation=localSamples(layout,payload,c,seed)
rx=complex(zeros(layout.physicalSymbolCount,c.samplesPerSymbol));
bins=zeros(layout.physicalSymbolCount,1); bins(layout.dataRows)=payload.physicalBins;
t=(0:c.samplesPerSymbol-1)/c.sampleRateHz;
stream=RandStream('mt19937ar','Seed',seed);
for row=1:layout.physicalSymbolCount
    time=layout.physicalStartTimeSec(row)+t;
    % Independent symbol noise forces genuinely different VP observations.
    phase=2*pi*c.fftBinSpacingHz*(.22*time+.5*.30*time.^2);
    noise=.018*(randn(stream,1,c.samplesPerSymbol)+1i*randn(stream,1,c.samplesPerSymbol));
    rx(row,:)=v4ModulateSymbol(bins(row),c).*exp(1i*phase)+noise;
end
observation=struct('rxPhysical',rx,'layout',layout);
end

function localOriginalPaths(sf)
if sf==7
    addpath('D:\codex\sf7\comparison_experiments\sf7_symbol_vp_four_curves\src\vendor','-begin');
else
    parent='D:\codex\Lora(eg)\comparison_experiments\stage55_sf12_sf11_flow_v4_noldro';
    addpath(genpath(parent),'-begin');
    original='D:\codex\Lora（SER performance of different estimation strategies）';
    addpath(fullfile(original,'senlora_symmetric_v8'),'-begin');
    addpath(fullfile(original,'senlora_symmetric_v8_symbol_vp'),'-begin');
end
end
