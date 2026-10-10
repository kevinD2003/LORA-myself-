function outputs = runExp1Ablation()
%RUNEXP1ABLATION Stage55 vs VP-off on the same Formal packet identities.

exp1SetupPaths();
config = exp1Config();
exp1ValidateFrozenParent(config);
indices = zeros(size(config.ablationOrbitStartSec));
for index = 1:numel(indices)
    indices(index) = find(config.orbitStartSec == ...
        config.ablationOrbitStartSec(index),1);
end
for index = 1:numel(indices)
    for snrIndex = 1:numel(config.snrDb)
        exp1RunCell('ablation',indices(index),config.snrDb(snrIndex), ...
            config.ablationPackets,'MethodSet','ablation', ...
            'SeedPhase','formal','SeedMode','registered');
    end
end
outputs = aggregateExp1Results('ablation');
plotExp1Results('ablation');
end

