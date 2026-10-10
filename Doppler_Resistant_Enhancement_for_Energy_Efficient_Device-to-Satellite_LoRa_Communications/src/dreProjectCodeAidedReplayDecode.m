function result = dreProjectCodeAidedReplayDecode(observation,projectConfig,rawBins)
%DREPROJECTCODEAIDEDREPLAYDECODE Robust LR followed by CR3-aided IQ replay.
%   The paper-native ten-point/Theil-Sen receiver supplies the first hard
%   decisions.  Hard Hamming decisions are re-encoded, a robust line is
%   fitted to the corresponding centroid errors, and the original IQ is
%   replayed after CFO/rate compensation.  No midamble, orbit state, SNR,
%   or transmitted payload value is used.

arguments
    observation (1,1) struct
    projectConfig (1,1) struct
    rawBins double = []
end

c = projectConfig.v4;
layout = observation.layout;
pilots = observation.rxPhysical(layout.bootstrapRows,:);
modeParameters = struct('maximumRateBinsPerSec',20, ...
    'modeLargeToCentralRatio',0.75);
modeEvidence = v4Stage55ObservableModeSelectorV10( ...
    pilots,c,modeParameters);
if modeEvidence.staticSelected
    parameters = v4LoadMethodAlignedR3ParametersV1();
    common = v4CommonBootstrap(pilots,c, ...
        SearchStepBins=parameters.searchStepBins);
    result = v4HuangStaticDecode(observation,common,c);
    result.methodName = 'Dietl robust replay, observable static branch';
    result.methodId = 'dietl-code-aided-replay-v3';
    result.modeEvidence = modeEvidence;
    result.receiverMode = 'observable-static';
    result.usesSnrInput = false;
    result.knownMidamblesUsed = 0;
    result.usesCodeAidedReplay = false;
    result.observableQuality = median(common.peakRatio);
    result.replayQualityThreshold = 5.5;
    return
end
parameters = v4LoadMethodAlignedR3ParametersV1();
common = v4CommonBootstrap(pilots,c, ...
    SearchStepBins=parameters.searchStepBins);
observableQuality = median(common.peakRatio);
replayQualityThreshold = 5.5;
if observableQuality < replayQualityThreshold
    result = v4Stage55UnifiedDecodeV16(observation,common,c);
    result.methodName = 'Dietl robust replay, observable safety branch';
    result.methodId = 'dietl-code-aided-replay-v3';
    result.modeEvidence = modeEvidence;
    result.receiverMode = 'observable-safety-dynamic';
    result.usesSnrInput = false;
    result.knownMidamblesUsed = 0;
    result.usesCodeAidedReplay = false;
    result.observableQuality = observableQuality;
    result.replayQualityThreshold = replayQualityThreshold;
    return
end
rows = [layout.bootstrapRows;layout.dataRows];
if isempty(rawBins)
    estimate = dreEstimatePaperCentroids10( ...
        observation.rxPhysical(rows,:),struct( ...
        'samplesPerSymbol',c.samplesPerSymbol,'zeroPaddingFactor',4));
    rawBins = estimate.rawBins;
else
    rawBins = double(rawBins(:));
end
if numel(rawBins) ~= numel(rows)
    error('DRE:CodeAidedRawBinShape', ...
        'Expected one centroid for every preamble and data symbol.');
end

initial = dreProjectRefinedLRDecode(observation,projectConfig, ...
    8,'theil-sen',rawBins);
hardBits = initial.hardDecodedDataBits;
positions = double(rows-1);
prior = [initial.linearRegression.observedErrorBins(1:c.bootstrapPilotCount); ...
    initial.linearRegression.predictedErrorBins];
maximumReplays = 3;
replayHistory = repmat(struct('slopeBinsPerSymbol',NaN, ...
    'interceptBins',NaN,'changedBits',NaN),maximumReplays,1);
decoded = [];
for replay = 1:maximumReplays
    reencoded = localEncodeHardBits(hardBits,c);
    labels = [zeros(c.bootstrapPilotCount,1);reencoded];
    base = rawBins-labels;
    observed = base+round((prior-base)/c.samplesPerSymbol)*c.samplesPerSymbol;
    [slope,intercept] = localTheilSen(positions,observed);
    predicted = slope*positions+intercept;
    compensated = complex(zeros(c.payloadSymbolCount,c.samplesPerSymbol));
    rateBinsPerSec = slope/c.symbolDurationSec;
    for data = 1:c.payloadSymbolCount
        selected = c.bootstrapPilotCount+data;
        physicalRow = layout.dataRows(data);
        compensated(data,:) = v4CompensateSymbol( ...
            observation.rxPhysical(physicalRow,:),0,predicted(selected), ...
            rateBinsPerSec,c);
    end
    decoded = v4DecodePayload(compensated,c,common.noisePower);
    nextBits = decoded.hardDataBits;
    replayHistory(replay).slopeBinsPerSymbol = slope;
    replayHistory(replay).interceptBins = intercept;
    replayHistory(replay).changedBits = sum(nextBits(:)~=hardBits(:));
    prior = predicted;
    if isequal(nextBits,hardBits)
        replayHistory = replayHistory(1:replay);
        hardBits = nextBits;
        break
    end
    hardBits = nextBits;
    if replay == maximumReplays
        replayHistory = replayHistory(1:replay);
    end
end

result = struct('methodName','Dietl code-aided robust replay', ...
    'methodId','dietl-code-aided-replay-v3', ...
    'detectedPhysicalBins',decoded.hardPhysicalBins, ...
    'hardDecodedDataBits',decoded.hardDataBits, ...
    'softDecodedDataBits',decoded.softDataBits, ...
    'initialReceiver',initial,'replayHistory',replayHistory, ...
    'modeEvidence',modeEvidence,'receiverMode','code-aided-dynamic', ...
    'observableQuality',observableQuality, ...
    'replayQualityThreshold',replayQualityThreshold, ...
    'usesPayloadTruth',false,'usesOrbitTruth',false, ...
    'usesSnrInput',false,'knownMidamblesUsed',0, ...
    'usesCodeAidedReplay',true,'centroidSampleCount',10, ...
    'replayCount',numel(replayHistory));
end

function physical = localEncodeHardBits(dataBits,c)
physical = zeros(c.payloadSymbolCount,1);
for block = 1:c.hammingBlockCount
    data = double(dataBits(:,:,block));
    parity = mod([data(:,1)+data(:,2)+data(:,4), ...
        data(:,1)+data(:,3)+data(:,4), ...
        data(:,2)+data(:,3)+data(:,4)],2);
    gray = v4DiagonalInterleave([data parity],c);
    rows = (block-1)*c.hammingCodewordLength+(1:c.hammingCodewordLength);
    physical(rows) = double(v4GrayDecode(uint32(gray)));
end
end

function [slope,intercept] = localTheilSen(x,y)
x = double(x(:)); y = double(y(:));
count = numel(x);
pairSlopes = zeros(count*(count-1)/2,1);
index = 0;
for first = 1:count-1
    for second = first+1:count
        index = index+1;
        pairSlopes(index) = (y(second)-y(first))/(x(second)-x(first));
    end
end
slope = median(pairSlopes);
intercept = median(y-slope*x);
end
