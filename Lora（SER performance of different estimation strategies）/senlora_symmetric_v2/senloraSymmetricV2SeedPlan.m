function ledger = senloraSymmetricV2SeedPlan(config,plan,phase,cellIndex,snrDb,packetId)
%SENLORASYMMETRICV2SEEDPLAN Disjoint seed domains for V2.

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
        error('EXP5V2:SeedPhase','Unknown phase %s.',phase);
end
key = struct('planVersion',plan.identity,'phase',phase, ...
    'track','symmetric-orbit','channel','AWGN', ...
    'comparisonMode','static-base-lobo-replay','snrDb',snrDb, ...
    'replicateId',packetId,'packetId',packetId, ...
    'eventType','paired-frame','eventIndex',cellIndex,'sampleIndex',0);
ledger = v4EventRandomLedger(rootSeed,key);
ledger.seedPhase = phase;
ledger.configIdentity = config.experimentId;
end
