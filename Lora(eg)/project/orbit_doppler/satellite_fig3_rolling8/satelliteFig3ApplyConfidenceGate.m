function gate = satelliteFig3ApplyConfidenceGate(tracker, soft, config, model, sampleSnrDb)
%SATELLITEFIG3APPLYCONFIDENCEGATE Apply trained, receiver-only pilot gate.
%   MODEL was trained offline.  This function has no transmitted symbols,
%   truth CFO, or channel truth in its inputs.

arguments
    tracker (1,1) struct
    soft (1,1) struct
    config (1,1) struct
    model (1,1) struct
    sampleSnrDb (1,1) double
end

features = satelliteFig3PilotConfidenceFeatures(tracker,soft,config);
z = (features.matrix-model.mu)./model.sigma;
posterior = localSigmoid([ones(size(z,1),1),z]*model.beta);
threshold = interp1(model.snrGridDb,model.posteriorThreshold,sampleSnrDb, ...
    'nearest','extrap');
acceptedPayload = features.candidateMask & posterior >= threshold;
acceptedMask = false(numel(tracker.detectedWaveformBins),1);
acceptedMask(features.payloadRows) = acceptedPayload;
acceptedMask(1:config.bootstrapPilotCount) = true;
gate = struct( ...
    'acceptedMask',acceptedMask, 'acceptedPayload',acceptedPayload, ...
    'posterior',posterior, 'threshold',threshold, ...
    'features',features, 'estimatedSampleSnrDb',sampleSnrDb);
end

function value = localSigmoid(x)
value = zeros(size(x));
positive = x >= 0;
value(positive) = 1./(1+exp(-x(positive)));
ex = exp(x(~positive));
value(~positive) = ex./(1+ex);
end
