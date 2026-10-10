function ledger = senloraSymmetricV3SeedPlan(config,plan,phase,cellIndex,snrDb,packetId)
%SENLORASYMMETRICV3SEEDPLAN Disjoint seed domains for V3.

phase = lower(char(phase));
switch phase
    case 'mechanism'
        rootSeed = plan.mechanismRootSeed;
    case 'smoke'
        rootSeed = plan.smokeRootSeed;
    case 'review'
        rootSeed = plan.reviewRootSeed;
    case 'formal'
        rootSeed = plan.formalRootSeed;
    otherwise
        error('EXP5V3:SeedPhase','Unknown phase %s.',phase);
end
key = struct('planVersion',plan.identity,'phase',phase, ...
    'track','symmetric-orbit','channel','AWGN', ...
    'comparisonMode','parent-safe-block-medoid','snrDb',snrDb, ...
    'replicateId',packetId,'packetId',packetId, ...
    'eventType','paired-frame','eventIndex',cellIndex,'sampleIndex',0);
ledger = v4EventRandomLedger(rootSeed,key);
ledger.seedPhase = phase;
ledger.configIdentity = config.experimentId;
end
