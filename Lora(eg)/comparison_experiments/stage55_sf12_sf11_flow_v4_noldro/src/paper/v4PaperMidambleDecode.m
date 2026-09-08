function result = v4PaperMidambleDecode(observation,bootstrap,config,parameters)
%V4PAPERMIDAMBLEDECODE Known Midamble, n_int=3, cumulative residual CFO.

v4ValidateReceiverParameters(parameters);
layout = observation.layout;
[phaseState,currentCfo] = v4BootstrapStateAtSymbol( ...
    bootstrap,config.bootstrapPilotCount,config);
compensatedData = complex(zeros(config.payloadSymbolCount,config.samplesPerSymbol));
estimatedCfoBins = nan(config.payloadSymbolCount,1);
explicitAccepted = false(config.paperMidambleCount,1);
firstEffectiveDataIndex = nan(config.paperMidambleCount,1);
midamble = 0;
for row = config.bootstrapPilotCount+1:layout.physicalSymbolCount
    compensated = v4CompensateSymbol(observation.rxPhysical(row,:), ...
        phaseState,currentCfo,0,config);
    cfoForAdvance = currentCfo;
    if layout.kind(row) == "data"
        data = layout.dataIndex(row);
        compensatedData(data,:) = compensated;
        estimatedCfoBins(data) = currentCfo;
    elseif layout.kind(row) == "midamble"
        midamble = midamble+1;
        residual = v4PhaseRotationEstimate(compensated,0,config, ...
            parameters.residualSearchBins);
        currentCfo = currentCfo+residual.offsetBins;
        explicitAccepted(midamble) = true;
        nextData = layout.midambleAfterDataIndex(midamble)+1;
        if nextData <= config.payloadSymbolCount
            firstEffectiveDataIndex(midamble) = nextData;
        end
    end
    phaseState = angle(exp(1i*(phaseState+2*pi*cfoForAdvance)));
end
decoded = v4DecodePayload(compensatedData,config,bootstrap.noisePower);
result = struct('methodName',config.methodNames{3}, ...
    'detectedPhysicalBins',decoded.hardPhysicalBins, ...
    'hardDecodedDataBits',decoded.hardDataBits, ...
    'softDecodedDataBits',decoded.softDataBits, ...
    'estimatedCfoBins',estimatedCfoBins, ...
    'virtualPilotAccepted',false(config.payloadSymbolCount,1), ...
    'explicitMidambleAccepted',explicitAccepted, ...
    'pilotFirstEffectiveDataIndex',firstEffectiveDataIndex, ...
    'bootstrap',bootstrap,'usesPayloadTruth',false, ...
    'usesOrbitTruth',false,'usesPayloadFeedback',false, ...
    'paperMidambleInterval',config.paperMidambleInterval, ...
    'fftCount',config.payloadSymbolCount+config.paperMidambleCount);
end
