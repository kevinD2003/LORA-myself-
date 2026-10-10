function plan = senloraSymmetricV2Config(config)
%SENLORASYMMETRICV2CONFIG Leave-one-block-out SenLoRa candidate settings.

plan = struct();
plan.identity = 'EXP5-SENLORA-SYMMETRIC-UPPER-V2';
plan.receiverVersion = 'SenLoRa-local-LOBO-quadratic-replay-v2';
plan.mechanismRootSeed = 994000000;
plan.smokeRootSeed = 995000000;
plan.reviewRootSeed = 996000000;
plan.formalRootSeed = 997000000;
plan.smokePackets = 5;
plan.reviewPackets = 20;
plan.snrDb = -21;
plan.negativeOrbitStartSec = -366:45.75:0;
plan.frameDurationSec = config.frameDurationSec;
plan.targetCase1Ser = 2e-3;
plan.targetCenterSer = 1e-2;
plan.refinementIterations = 3;
plan.residualCandidatesBins = (-1.5:0.1:1.5).';
plan.residualPeakRatioMinimum = 1.15;
plan.residualInnovationLimitBins = 1.25;
plan.minimumCodewordMargin = 0;
plan.maximumMeasurementsPerBlock = 2;
plan.localFitPointCount = 12;
plan.huberThresholdBins = 0.20;
plan.polynomialOrder = 2;
plan.rateBankOffsetsBinsPerSec = (-0.6:0.15:0.6).';
plan.lowDriftDefaultBins = 1.0;
plan.staticScoreFloorPerSymbol = -0.05;
plan.branchGainPerSymbol = 0.05;
plan.usesOrbitTruthInReceiver = false;
plan.usesTargetSerInReceiver = false;
end
