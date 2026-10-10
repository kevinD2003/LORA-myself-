function ledger = reviewFirstSeedPlan(config,review,phase,cellIndex,snrDb,packetId)
%REVIEWFIRSTSEEDPLAN Disjoint keyed seed domains for EXP3.

phase = lower(char(phase));
switch phase
    case 'gate_calibration'
        rootSeed = review.calibrationRootSeed;
    case 'vp_calibration'
        rootSeed = review.vpCalibrationRootSeed;
    case 'smoke'
        rootSeed = review.smokeRootSeed;
    case 'review'
        rootSeed = review.reviewRootSeed;
    case 'formal'
        rootSeed = review.formalRootSeed;
    case 'refinement'
        rootSeed = review.refinementRootSeed;
    otherwise
        error('EXP3:SeedPhase','Unknown phase %s.',phase);
end
key = struct('planVersion',review.identity,'phase',phase, ...
    'track','orbit-position','channel','AWGN', ...
    'comparisonMode','dual-hypothesis-packet-replay','snrDb',snrDb, ...
    'replicateId',packetId,'packetId',packetId, ...
    'eventType','paired-frame','eventIndex',cellIndex, ...
    'sampleIndex',0);
ledger = v4EventRandomLedger(rootSeed,key);
ledger.seedPhase = phase;
ledger.configIdentity = config.experimentId;
end
