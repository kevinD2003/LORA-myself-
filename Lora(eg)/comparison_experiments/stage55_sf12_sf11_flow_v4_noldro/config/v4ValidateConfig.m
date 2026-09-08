function v4ValidateConfig(config)
%V4VALIDATECONFIG Enforce the non-calibrated identity fixed by the V4 plan.

mustEqual(config.physicalSf,12,'physicalSf');
mustEqual(config.effectiveDataSf,12,'effectiveDataSf');
mustEqual(config.dataAlphabetSize,4096,'dataAlphabetSize');
mustEqual(config.dataBinSpacing,1,'dataBinSpacing');
mustEqual(config.bandwidthHz,125000,'bandwidthHz');
mustEqual(config.sampleRateHz,125000,'sampleRateHz');
mustEqual(config.samplesPerSymbol,4096,'samplesPerSymbol');
mustEqual(config.symbolDurationSec,0.032768,'symbolDurationSec');
mustEqual(config.cr,3,'cr');
mustEqual(config.hammingBlockCount,16,'hammingBlockCount');
mustEqual(config.payloadSymbolCount,112,'payloadSymbolCount');
mustEqual(config.informationBitCount,768,'informationBitCount');
mustEqual(config.bootstrapPilotCount,8,'bootstrapPilotCount');
mustEqual(config.maxSenLoRaIterations,5,'maxSenLoRaIterations');
mustEqual(config.virtualPilotHistoryLength,8,'virtualPilotHistoryLength');
mustEqual(config.paperMidambleInterval,3,'paperMidambleInterval');
mustEqual(config.paperMidambleCount,37,'paperMidambleCount');
mustEqual(config.commonTimelineSymbolCount,157,'commonTimelineSymbolCount');
if config.usesOrbitPrior
    error('V4:OrbitPriorForbidden','V4 receiver paths cannot use orbit truth priors.');
end
if numel(unique(struct2array(config.seeds))) ~= numel(struct2array(config.seeds))
    error('V4:SeedDomainOverlap','Random seed-domain bases must be disjoint.');
end
end

function mustEqual(actual,expected,name)
if ~isequal(actual,expected)
    error('V4:ConfigurationIdentity','%s must equal %g.',name,expected);
end
end
