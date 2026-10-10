function result = reviewStaticHypothesis(observation,bootstrap,c)
%REVIEWSTATICHYPOTHESIS Instrumented copy of the frozen static algorithm.

layout = observation.layout;
[phaseState,fixedCfo] = v4BootstrapStateAtSymbol( ...
    bootstrap,c.bootstrapPilotCount,c);
compensatedData = complex(zeros(c.payloadSymbolCount,c.samplesPerSymbol));
estimatedCfoBins = nan(c.payloadSymbolCount,1);
peakMetric = nan(c.payloadSymbolCount,1);
peakRatio = nan(c.payloadSymbolCount,1);
for row = c.bootstrapPilotCount+1:layout.physicalSymbolCount
    compensated = v4CompensateSymbol(observation.rxPhysical(row,:), ...
        phaseState,fixedCfo,0,c);
    if layout.kind(row)=="data"
        data = layout.dataIndex(row);
        compensatedData(data,:) = compensated;
        estimatedCfoBins(data) = fixedCfo;
        likelihood = v4SymbolLikelihood(compensated,c,bootstrap.noisePower);
        peakMetric(data) = likelihood.peakMetric;
        peakRatio(data) = likelihood.peakRatio;
    end
    phaseState = angle(exp(1i*(phaseState+2*pi*fixedCfo)));
end
decoded = v4DecodePayload(compensatedData,c,bootstrap.noisePower);
result = struct('compensatedData',compensatedData, ...
    'detectedPhysicalBins',decoded.hardPhysicalBins, ...
    'estimatedCfoBins',estimatedCfoBins,'peakMetric',peakMetric, ...
    'peakRatio',peakRatio,'fixedCfoBins',fixedCfo,'decoded',decoded, ...
    'usesPayloadTruth',false,'usesOrbitTruth',false);
end
