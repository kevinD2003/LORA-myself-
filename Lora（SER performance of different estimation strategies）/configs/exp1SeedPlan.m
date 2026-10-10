function ledger = exp1SeedPlan(config,phase,orbitIndex,snrDb,packetId,seedMode)
%EXP1SEEDPLAN Stable packet identity and separated parent RNG streams.

if nargin < 6
    seedMode = 'registered';
end
if strcmpi(seedMode,'legacy')
    if abs(snrDb-config.parentEndpointSnrDb) > 1e-12
        error('EXP1:LegacySeedSnr','Legacy smoke seeds require -21 dB.');
    end
    if orbitIndex == 1
        parentCaseIndex = 1;
    elseif orbitIndex == numel(config.orbitStartSec)
        parentCaseIndex = 2;
    else
        error('EXP1:LegacySeedOrbit','Legacy smoke seeds are endpoint-only.');
    end
    parentSnrIndex = find((-30:-21) == snrDb,1);
    key = struct('planVersion','unified-v16-test','phase','paired-grid', ...
        'track','B-method-aligned','channel','AWGN', ...
        'comparisonMode','case-anchor-controlled','snrDb',snrDb, ...
        'replicateId',packetId,'packetId',packetId, ...
        'eventType','paired-frame', ...
        'eventIndex',parentCaseIndex*100+parentSnrIndex,'sampleIndex',0);
    ledger = v4EventRandomLedger(config.legacySeedRoot,key);
    ledger.cellId = sprintf('legacy_case_%d_snr_%g',parentCaseIndex,snrDb);
    ledger.seedPhase = 'legacy-parent-v23';
    return
end

phase = lower(char(phase));
if ~isfield(config.seedRoots,phase)
    error('EXP1:SeedPhase','Unknown registered seed phase: %s.',phase);
end
snrIndex = find(abs(config.snrDb-snrDb) < 1e-10,1);
if isempty(snrIndex)
    error('EXP1:SeedSnr','SNR %.12g is not in the frozen matrix.',snrDb);
end
key = struct('planVersion',config.experimentId,'phase',phase, ...
    'track','orbit-position','channel','AWGN', ...
    'comparisonMode','common-waveform','snrDb',snrDb, ...
    'replicateId',packetId,'packetId',packetId, ...
    'eventType','paired-frame','eventIndex',orbitIndex*100+snrIndex, ...
    'sampleIndex',0);
ledger = v4EventRandomLedger(config.seedRoots.(phase),key);
ledger.cellId = exp1CellId(config.orbitStartSec(orbitIndex),snrDb);
ledger.seedPhase = phase;
end

