function result = sf12PairedFrameSimulation( ...
    cfg,caseName,snrDb,packetIndex,seedDomain,snrIndex)
%SF12PAIREDFRAMESIMULATION One paired packet and receiver-blind evaluation.

seeds = sf12RandomSeeds(cfg,seedDomain,caseName,snrIndex,packetIndex);
frame = sf12GenerateCommonFrame(cfg,caseName,snrDb,seeds);
bootstrap = sf12CommonPointBootstrap( ...
    frame.observation.rxInitialDownchirp,cfg);
paperTimer = tic;
paper = sf12PaperMidambleDecode(frame.observation,bootstrap,cfg);
paperRuntimeSec = toc(paperTimer);
stage55Timer = tic;
stage55 = sf12Stage55VpSerDecode(frame.observation,bootstrap,cfg);
stage55RuntimeSec = toc(stage55Timer);
truth = frame.truth;

paperErrors = paper.detectedSymbols ~= truth.payloadSymbols;
stageErrors = stage55.detectedSymbols ~= truth.payloadSymbols;
falseAccepted = stage55.virtualPilotAccepted & stageErrors;
result.caseName = string(caseName);
result.snrDb = snrDb;
result.packetIndex = packetIndex;
result.bootstrapCfoHz = bootstrap.cfoHz;
result.paperInitialCfoHz = paper.initialCfoHz;
result.stage55InitialCfoHz = stage55.initialCfoHz;
result.paperInitialPhaseRad = paper.initialPhaseRad;
result.stage55InitialPhaseRad = stage55.initialPhaseRad;
result.paperSymbolErrors = nnz(paperErrors);
result.stage55SymbolErrors = nnz(stageErrors);
result.totalDataSymbols = cfg.frame.payloadSymbolCount;
result.paperCfoSquaredError = sum((paper.estimatedCfoHz- ...
    truth.dataCfoHz).^2);
result.stage55CfoSquaredError = sum((stage55.estimatedCfoHz- ...
    truth.dataCfoHz).^2);
result.cfoSampleCount = cfg.frame.payloadSymbolCount;
result.stage55AcceptedVirtualPilots = nnz(stage55.virtualPilotAccepted);
result.stage55FalseAcceptedVirtualPilots = nnz(falseAccepted);
result.paperEffectiveMidambles = nnz(paper.explicitMidambleAccepted);
result.stage55ExplicitMidambleAccepted = ...
    nnz(stage55.explicitMidambleAccepted);
result.paperVirtualPilotAccepted = nnz(paper.virtualPilotAccepted);
result.paperFirstEffectiveDataIndex = paper.pilotFirstEffectiveDataIndex;
result.stage55FirstEffectiveDataIndex = stage55.pilotFirstEffectiveDataIndex;
paperEffective = paper.pilotFirstEffectiveDataIndex;
paperEffective = paperEffective(isfinite(paperEffective));
stageEffective = stage55.pilotFirstEffectiveDataIndex;
stageEffective = stageEffective(isfinite(stageEffective));
result.paperPilotImpactCoverageSymbols = sum( ...
    cfg.frame.payloadSymbolCount-paperEffective+1);
result.stage55PilotImpactCoverageSymbols = sum( ...
    cfg.frame.payloadSymbolCount-stageEffective+1);
result.paperRuntimeSec = paperRuntimeSec;
result.stage55RuntimeSec = stage55RuntimeSec;
result.paperFftCount = paper.fftCount;
result.stage55FftCount = stage55.fftCount;
result.payloadSeed = seeds.payloadSeed;
result.noiseSeed = seeds.noiseSeed;
result.channelSeed = seeds.channelSeed;
result.commonSampleFingerprint = frame.commonSampleFingerprint;
result.paperInputFingerprint = frame.commonSampleFingerprint;
result.stage55InputFingerprint = frame.commonSampleFingerprint;
result.payloadSymbols = truth.payloadSymbols;
result.trueDataCfoHz = truth.dataCfoHz;
result.paperEstimatedCfoHz = paper.estimatedCfoHz;
result.stage55EstimatedCfoHz = stage55.estimatedCfoHz;
result.stage55AcceptedMask = stage55.virtualPilotAccepted;
assert(result.paperInitialCfoHz == result.stage55InitialCfoHz);
assert(result.paperInitialPhaseRad == result.stage55InitialPhaseRad);
assert(result.stage55ExplicitMidambleAccepted == 0);
assert(result.paperVirtualPilotAccepted == 0);
assert(result.paperEffectiveMidambles == 7);
end
