function report = runExp1Smoke()
%RUNEXP1SMOKE Reproduce the first ten parent endpoint packets at -21 dB.

exp1SetupPaths();
config = exp1Config();
exp1ValidateFrozenParent(config);
first = exp1RunCell('smoke',1,config.parentEndpointSnrDb, ...
    config.smokePackets,'MethodSet','main','SeedMode','legacy', ...
    'SeedPhase','legacy');
last = exp1RunCell('smoke',numel(config.orbitStartSec), ...
    config.parentEndpointSnrDb,config.smokePackets, ...
    'MethodSet','main','SeedMode','legacy','SeedPhase','legacy');
report = exp1VerifyParentSmoke({first,last},config);
aggregateExp1Results('smoke');
if ~strcmp(report.status,'PASS')
    error('EXP1:SmokeMismatch','Parent endpoint smoke did not reproduce.');
end
end

