function plan = senloraSymmetricV8Config(config)
%SENLORASYMMETRICV8CONFIG Continuous-rate two-pass native-frame SenLoRa.

plan = struct();
plan.identity = 'EXP5-SENLORA-SYMMETRIC-NATIVE-V8-FROZEN';
plan.receiverVersion = 'SenLoRa-V8-joint-block-frozen-v1';
plan.mechanismRootSeed = 1030000000;
plan.smokeRootSeed = 1031000000;
plan.reviewRootSeed = 1032000000;
plan.formalRootSeed = 1033000000;
plan.snrDb = -21;
plan.negativeOrbitStartSec = -366:45.75:0;
plan.nativePhysicalSymbolCount = config.parent.bootstrapPilotCount+ ...
    config.parent.payloadSymbolCount;
plan.frameDurationSec = plan.nativePhysicalSymbolCount* ...
    config.parent.symbolDurationSec;
plan.driftBlendStartBins = 0.10;
plan.driftBlendEndBins = 0.80;
plan.maximumPasses = 2;
plan.mechanismPacketsPerMirrorPair = 20;
plan.reviewPacketsPerMirrorPair = 100;
plan.formalPacketsPerMirrorPair = 1000;
plan.parametersFrozen = true;
plan.frozenAt = '2026-09-28T00:00:00+08:00';
plan.frozenFromReview = 'joint-block-review-20-20-16';
plan.usesExplicitMidambles = false;
plan.usesOrbitTruthInReceiver = false;
plan.usesTargetSerInReceiver = false;
end
