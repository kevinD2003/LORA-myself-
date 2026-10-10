function config = dreProjectConfig()
%DREPROJECTCONFIG Frozen bridge into the current V4 project conditions.

config = struct();
config.identity = 'dietl-lr-on-v4-no-ldro-v1';
config.caseStartTimeSec = [-366 0].';
config.caseNames = {'high-shift','high-rate'};
config.snrDb = [-27 -24 -21].';
config.packetCountPerCell = 100;
config.zeroPaddingFactor = 4;
config.centroidSampleCount = 10;
config.commonBootstrapSearchStepBins = 0.05;
config.randomSeedRoot = 946000000;
config.methodIds = {'huang-unified-v2','stage55-unified-v16', ...
    'paper-midamble-adapted-v6','dietl-fixed-lr-v1','dietl-adaptive-lr-v1'};
config.methodLabels = {'Huang-PREC','Stage55 VP-quality','Midamble-Point', ...
    'Dietl Fixed LR','Dietl Adaptive LR'};
config.algorithmVersion = 'five-receiver-paired-v4-comparison-v1';
end

