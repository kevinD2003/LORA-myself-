function result = senloraSymmetricV6Decode(observation,common,config,plan)
%SENLORASYMMETRICV6DECODE Override Static only on strong dynamic consensus.

v3 = senloraSymmetricV3Decode(observation,common,config,plan);
result = v3;
override = false;
rateLoboAgree = false;
staticScore = NaN;
bestDynamicScore = NaN;
if v3.decision.parentStaticProtected
    n = config.parent.payloadSymbolCount;
    scores = v3.decision.v2BranchScores(:).'/n;
    staticScore = scores(1);
    bestDynamicScore = max(scores(3:4));
    rateBins = v3.rateBank.selectedDecoded.hardPhysicalBins(:);
    loboBins = v3.loboHypothesis.decoded.hardPhysicalBins(:);
    rateLoboAgree = isequal(rateBins,loboBins);
    override = rateLoboAgree && ...
        bestDynamicScore>= ...
        plan.staticOverrideDynamicScoreFloorPerSymbol && ...
        bestDynamicScore-staticScore>=plan.staticOverrideGainPerSymbol;
    if override
        dynamicPlan = plan;
        dynamicPlan.staticScoreFloorPerSymbol = Inf;
        result = senloraSymmetricV3Decode( ...
            observation,common,config,dynamicPlan);
        if result.decision.parentStaticProtected
            error('EXP5V6:StaticOverride', ...
                'Dynamic replay remained Static-protected.');
        end
    end
end

result.v3CandidateDetectedPhysicalBins = v3.detectedPhysicalBins(:);
result.decision.v6StaticOverride = override;
result.decision.v6RateLoboAgree = rateLoboAgree;
result.decision.v6StaticScorePerSymbol = staticScore;
result.decision.v6BestDynamicScorePerSymbol = bestDynamicScore;
result.methodName = 'SenLoRa-Symmetric-Static-Consensus-Override';
result.methodId = 'senlora-symmetric-v6';
result.algorithmVersion = plan.receiverVersion;
result.usesPayloadTruth = false;
result.usesOrbitTruth = false;
result.usesCaseIdentity = false;
result.usesSnrInput = false;
result.usesTargetSer = false;
end
