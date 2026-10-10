function plan = senloraSymmetricV6Config(config)
%SENLORASYMMETRICV6CONFIG Independent static-consensus override study.

plan = senloraSymmetricV3Config(config);
plan.identity = 'EXP5-SENLORA-SYMMETRIC-UPPER-V6';
plan.receiverVersion = 'SenLoRa-static-consensus-override-v6';
plan.mechanismRootSeed = 1013000000;
plan.smokeRootSeed = 1014000000;
plan.reviewRootSeed = 1017000000;
plan.formalRootSeed = 1016000000;
plan.staticOverrideDynamicScoreFloorPerSymbol = -0.002;
plan.staticOverrideGainPerSymbol = 0.005;
end
