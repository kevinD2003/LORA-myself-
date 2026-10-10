function outputs = runExp1Pilot()
%RUNEXP1PILOT Five anchors at -24 dB with 200 paired packets per cell.

exp1SetupPaths();
config = exp1Config();
exp1ValidateFrozenParent(config);
for orbitIndex = 1:numel(config.orbitStartSec)
    exp1RunCell('pilot',orbitIndex,-24,config.pilotPackets, ...
        'MethodSet','main','SeedPhase','pilot','SeedMode','registered');
end
outputs = aggregateExp1Results('pilot');
plotExp1Results('pilot');
end

