function plan = senloraSymmetricV3Config(config)
%SENLORASYMMETRICV3CONFIG Parent-safe block-consensus candidate settings.

plan = senloraSymmetricV2Config(config);
plan.identity = 'EXP5-SENLORA-SYMMETRIC-UPPER-V3';
plan.receiverVersion = 'SenLoRa-parent-safe-block-medoid-v3';
plan.mechanismRootSeed = 1001000000;
plan.smokeRootSeed = 1002000000;
plan.reviewRootSeed = 1003000000;
plan.formalRootSeed = 1004000000;
plan.mechanismPackets = 20;
plan.parentStaticHighCodeScoreProtection = true;
plan.dynamicSelection = 'v2-default-with-medoid-score-veto';
end
