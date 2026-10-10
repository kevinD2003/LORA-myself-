function config = exp1Config()
%EXP1CONFIG Frozen configuration for EXP1-SF12-ORBIT-POSITION-V2.

projectRoot = fileparts(fileparts(mfilename('fullpath')));
codexRoot = fileparts(projectRoot);
parentRoot = fullfile(codexRoot,'Lora(eg)','comparison_experiments', ...
    'stage55_sf12_sf11_flow_v4_noldro');
if exist('sf12NoLdroSf11FlowConfig','file') ~= 2
    addpath(genpath(parentRoot),'-end');
end
parent = sf12NoLdroSf11FlowConfig();

config = struct();
config.experimentId = 'EXP1-SF12-ORBIT-POSITION-V2';
config.specVersion = '2026-09-21-v2';
config.projectRoot = projectRoot;
config.parentRoot = parentRoot;
config.parentBaseGitCommit = '4d509fd5c2c6e0656916c4a8dd82a7ff56686f39';
config.parentSourceState = 'base-commit-plus-explicitly-locked-local-files';
config.parent = parent;
config.orbitStartSec = [-366 -274.5 -183 -91.5 0];
config.snrDb = [-24 -21.12];
config.parentEndpointSnrDb = -21;
config.ablationOrbitStartSec = [-366 -91.5 0];
config.methodNames = {'Huang','Paper','Stage55','Ideal'};
config.ablationMethodNames = {'Stage55','Stage55-VP-off'};
config.smokePackets = 10;
config.pilotPackets = 200;
config.formalPackets = 1000;
config.ablationPackets = 1000;
config.maximumRefinementPackets = 5000;
config.bootstrapDraws = 10000;
config.checkpointEveryPackets = 5;
config.seedRoots = struct('pilot',921000000,'formal',922000000, ...
    'refinement',923000000);
config.legacySeedRoot = 884000000;
config.failurePolicy = 'count-all-data-symbols-and-information-bits-wrong';
config.perDefinition = 'at-least-one-data-symbol-error';
config.channelModel = 'AWGN';
config.initialChannelPhaseRad = 0;
config.frameDurationSec = parent.commonTimelineSymbolCount*parent.symbolDurationSec;
config.lastSampleOffsetSec = ...
    (parent.commonTimelineSymbolCount*parent.samplesPerSymbol-1)/parent.sampleRateHz;
config.parentManifestPath = fullfile(projectRoot,'configs', ...
    'parent_source_manifest.json');

exp1ValidateConfig(config);
end
