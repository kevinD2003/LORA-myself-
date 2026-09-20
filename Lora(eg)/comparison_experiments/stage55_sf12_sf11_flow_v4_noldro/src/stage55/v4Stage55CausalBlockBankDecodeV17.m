function result=v4Stage55CausalBlockBankDecodeV17(observation,bootstrap,c,p,options)
%V4STAGE55CAUSALBLOCKBANKDECODEV17 Audit-correct wrapper for v16 behavior.
% The nested tracker records every VP label actually admitted by the
% Stage55 candidate tracker, even when the block-local output selector uses
% a no-VP recovery branch for the final decoded block.

arguments
    observation (1,1) struct
    bootstrap (1,1) struct
    c (1,1) struct
    p (1,1) struct
    options.CrossFrameRateBinsPerSec (1,1) double=NaN
    options.CrossFrameHistoryCount (1,1) double=0
end

result=v4Stage55CausalBlockBankDecodeV16(observation,bootstrap,c,p, ...
    CrossFrameRateBinsPerSec=options.CrossFrameRateBinsPerSec, ...
    CrossFrameHistoryCount=options.CrossFrameHistoryCount);
result.algorithmVersion='Stage55-B-causal-block-code-likelihood-bank-v17';
result.virtualPilotAccepted=result.tracker.pilotAccepted;
result.pilotFirstEffectivePhysicalRow=result.tracker.pilotAppliedAtPhysicalRow;
result.pilotAvailabilityPhysicalRow=result.tracker.pilotAvailabilityPhysicalRow;
result.activeHistoryCount=result.tracker.activeHistoryCount;
result.phasePairUsed=result.tracker.phasePairUsed;
result.vpAuditSource='candidate tracker actually receiving hard-label VPs';
result.usesPayloadTruth=false;
result.usesOrbitTruth=false;
end
