function decoded=acDecodeMethods(pair,config)
%ACDECODEMETHODS Frozen receivers; only received samples and layout enter.
% Truth, generator noise variance, channel coefficients, SNR, orbit start,
% and case identity are never read by this receiver boundary.
arguments
    pair (1,1) struct
    config (1,1) struct
end
identity=acMethodSources();
c=config.parent; plan=config.receiverPlan;
assert(ismember(c.physicalSf,[7 12]) && c.effectiveDataSf==c.physicalSf && ...
    c.dataBinSpacing==1 && c.dataAlphabetSize==2^c.physicalSf && ...
    c.samplesPerSymbol==2^c.physicalSf && c.cr==3 && ...
    c.payloadSymbolCount==112 && c.bootstrapPilotCount==8 && ...
    c.virtualPilotHistoryLength==8,'AllCurves:FrozenPhy','Requires SF7/SF12 no-LDRO CR3 and 112 chirps.');
assert(plan.nativePhysicalSymbolCount==120 && ...
    abs(plan.frameDurationSec-120*c.symbolDurationSec)<1e-12 && ...
    plan.driftBlendStartBins==.10 && plan.driftBlendEndBins==.80 && ...
    plan.parametersFrozen,'AllCurves:FrozenPlan','The V8 plan must stay frozen.');
native=localObservation(pair.native.observation,c,120);
pilot=localObservation(pair.pilot.observation,c,120+c.paperMidambleCount);
assert(isempty(native.layout.midambleRows) && ...
    numel(pilot.layout.midambleRows)==c.paperMidambleCount, ...
    'AllCurves:FrameLayout','Native/paper frame mismatch.');
p=v4LoadMethodAlignedR3ParametersV1();
runtime=struct('common',NaN,'PREC',NaN,'VP',NaN,'Paper',NaN);
failures=struct('PREC',false,'VP',false,'Paper',false);
messages=struct('PREC',"",'VP',"",'Paper',"");
prec=[]; vp=[]; common=[];
timer=tic;
try
    common=v4CommonBootstrap(native.rxPhysical(native.layout.bootstrapRows,:),c, ...
        SearchStepBins=p.searchStepBins);
    assert(isfinite(common.noisePower) && common.noisePower>0, ...
        'AllCurves:NoiseEstimate','Invalid received-preamble noise estimate.');
catch exception
    failures.PREC=true; failures.VP=true;
    messages.PREC=localFailure(exception); messages.VP=messages.PREC;
end
runtime.common=toc(timer);
if ~isempty(common) && ~failures.PREC
    timer=tic;
    try
        % Legacy name; its value is a received-preamble estimate.
        precInput=native; precInput.noiseVariance=common.noisePower;
        prec=localOutput(v4HuangPrecUnifiedDecodeV9(precInput,c),c);
    catch exception
        prec=[]; failures.PREC=true; messages.PREC=localFailure(exception);
    end
    runtime.PREC=toc(timer);
    timer=tic;
    try
        vp=senloraSymmetricV8SymbolVpDecode(native,common,struct('parent',c),plan, ...
            SymbolVpHistoryLength=8);
        vp=localOutput(vp,c);
        assert(vp.SymbolVpHistoryLength==8 && ...
            strcmp(vp.algorithmVersion,'SenLoRa-V8-symbol-vp-experiment-v1'), ...
            'AllCurves:WrongVpVersion','Symbol-VP Rolling-N8 is required.');
        assert(height(vp.symbolObservations)==112 && ...
            all(vp.fitLog.historyCount<=8), ...
            'AllCurves:VpHistory','VP must use at most eight individual symbol observations.');
    catch exception
        vp=[]; failures.VP=true; messages.VP=localFailure(exception);
    end
    runtime.VP=toc(timer);
end
timer=tic;
try
    paper=localOutput(prefecPaperNativeDecode(pilot,c),c);
catch exception
    paper=[]; failures.Paper=true; messages.Paper=localFailure(exception);
end
runtime.Paper=toc(timer);
% All real receivers finish before any evaluator is allowed to use truth.
noisePower=NaN; if ~isempty(common), noisePower=common.noisePower; end
decoded=struct('PREC',prec,'VP',vp,'Paper',paper, ...
    'noisePowerEstimate',noisePower,'runtimeSec',runtime, ...
    'failures',failures,'messages',messages, ...
    'sourceIdentity',identity,'allReceiversCompleted',true, ...
    'receiverInputPolicy','rxPhysical+layout; preamble-estimated noise only');
end

function message=localFailure(exception)
message=string(exception.identifier)+": "+string(exception.message);
end

function observation=localObservation(input,c,physicalCount)
observation=struct('rxPhysical',input.rxPhysical,'layout',input.layout);
assert(isequal(size(observation.rxPhysical),[physicalCount c.samplesPerSymbol]) && ...
    all(isfinite(observation.rxPhysical),'all'), ...
    'AllCurves:ObservationShape','Wrong or nonfinite physical frame.');
layout=observation.layout;
assert(layout.physicalSymbolCount==physicalCount && ...
    isequal(layout.bootstrapRows(:),(1:8).') && numel(layout.dataRows)==112 && ...
    all(layout.dataRows>8) && all(layout.dataRows<=physicalCount), ...
    'AllCurves:ObservationLayout','Expected eight upchirps followed by 112 data chirps.');
end

function result=localOutput(result,c)
bins=result.detectedPhysicalBins(:);
assert(numel(bins)==112 && all(isfinite(bins)) && ...
    all(bins==fix(bins) & bins>=0 & bins<c.dataAlphabetSize), ...
    'AllCurves:OutputAlphabet','Invalid native physical chirp decisions.');
assert(numel(result.estimatedCfoBins)==112 && ...
    all(isfinite(result.estimatedCfoBins)), ...
    'AllCurves:OutputEstimator','Invalid CFO output.');
result.symbolSource='native-FFT-hard-chirp-before-FEC';
result.serDecisionStage='raw-physical-chirp-before-FEC';
if isfield(result,'hardDecodedDataBits')
    bits=result.hardDecodedDataBits;
    assert(numel(bits)==c.informationBitCount && all(bits==0 | bits==1,'all'), ...
        'AllCurves:OutputBits','Invalid decoded information bits.');
    result.bitErrorStage='hard-FEC-decoded-information-bits';
else
    result.bitErrorStage='unavailable';
end
if ~isfield(result,'estimatedRateBinsPerSec')
    result.estimatedRateBinsPerSec=zeros(112,1);
end
assert(numel(result.estimatedRateBinsPerSec)==112 && ...
    all(isfinite(result.estimatedRateBinsPerSec)), ...
    'AllCurves:OutputRate','Invalid Doppler-rate output.');
end
