function outputs = runExp1Formal()
%RUNEXP1FORMAL Five anchors, two SNRs, 1000 paired packets per cell.

exp1SetupPaths();
config = exp1Config();
exp1ValidateFrozenParent(config);
for orbitIndex = 1:numel(config.orbitStartSec)
    for snrIndex = 1:numel(config.snrDb)
        exp1RunCell('formal',orbitIndex,config.snrDb(snrIndex), ...
            config.formalPackets,'MethodSet','main','SeedPhase','formal', ...
            'SeedMode','registered');
    end
end
outputs = aggregateExp1Results('formal');
plotExp1Results('formal');
end

