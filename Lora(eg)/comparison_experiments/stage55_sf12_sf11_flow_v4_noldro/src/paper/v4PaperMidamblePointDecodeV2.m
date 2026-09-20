function result = v4PaperMidamblePointDecodeV2(observation,c)
%V4PAPERMIDAMBLEPOINTDECODEV2 Paper-native piecewise-constant Point updates.
%
% The closest known bootstrap chirp provides the initial integer FFT-bin
% Point estimate.  Every known midamble then measures the full integer
% residual and updates the piecewise-constant CFO cumulatively.  The
% adaptation uses the available upchirp in place of the paper's closest
% synchronization downchirp; the Point estimator itself is otherwise the
% integer FFT estimator of (10), with n_int=3.

layout = observation.layout;
lastBootstrapRow = layout.bootstrapRows(end);
initial = v4PaperIntegerPointEstimate( ...
    observation.rxPhysical(lastBootstrapRow,:),0,c);
currentCfo = initial.offsetBins;
compensatedData = complex(zeros(c.payloadSymbolCount,c.samplesPerSymbol));
estimatedCfoBins = nan(c.payloadSymbolCount,1);
explicitAccepted = false(c.paperMidambleCount,1);
midambleResidualBins = nan(c.paperMidambleCount,1);
firstEffectiveDataIndex = nan(c.paperMidambleCount,1);
midamble = 0;
for row = c.bootstrapPilotCount+1:layout.physicalSymbolCount
    compensated = v4CompensateSymbol( ...
        observation.rxPhysical(row,:),0,currentCfo,0,c);
    if layout.kind(row) == "data"
        data = layout.dataIndex(row);
        compensatedData(data,:) = compensated;
        estimatedCfoBins(data) = currentCfo;
    elseif layout.kind(row) == "midamble"
        midamble = midamble+1;
        residual = v4PaperIntegerPointEstimate(compensated,0,c);
        currentCfo = currentCfo+residual.offsetBins;
        midambleResidualBins(midamble) = residual.offsetBins;
        explicitAccepted(midamble) = true;
        nextData = layout.midambleAfterDataIndex(midamble)+1;
        if nextData <= c.payloadSymbolCount
            firstEffectiveDataIndex(midamble) = nextData;
        end
    end
end
decoded = v4DecodePayload(compensatedData,c,observation.noiseVariance);
result = struct('methodName',c.methodNames{3}, ...
    'algorithmVersion','Paper-Midamble-Point-integer-full-FFT-v2', ...
    'detectedPhysicalBins',decoded.hardPhysicalBins, ...
    'hardDecodedDataBits',decoded.hardDataBits, ...
    'softDecodedDataBits',decoded.softDataBits, ...
    'estimatedCfoBins',estimatedCfoBins, ...
    'virtualPilotAccepted',false(c.payloadSymbolCount,1), ...
    'explicitMidambleAccepted',explicitAccepted, ...
    'pilotFirstEffectiveDataIndex',firstEffectiveDataIndex, ...
    'midambleResidualBins',midambleResidualBins, ...
    'initialPointEstimate',initial, ...
    'paperMidambleInterval',c.paperMidambleInterval, ...
    'integerEstimatorOnly',true,'usesPayloadTruth',false, ...
    'usesOrbitTruth',false,'usesPayloadFeedback',false, ...
    'usesDopplerRate',false, ...
    'fftCount',1+c.payloadSymbolCount+c.paperMidambleCount);
end
