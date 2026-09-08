function [tauBlock, tauGlobal] = updateConfidenceThreshold(confidence, alpha, state)
%UPDATECONFIDENCETHRESHOLD Compute local and EMA global thresholds.

arguments
    confidence (:,1) double
    alpha (1,1) double {mustBeGreaterThanOrEqual(alpha, 0), mustBeLessThanOrEqual(alpha, 1)}
    state = []
end

tauBlock = mean(confidence) + std(confidence, 0);

if isempty(state) || ~isfield(state, "tauGlobal") || isempty(state.tauGlobal)
    tauGlobal = tauBlock;
else
    tauGlobal = alpha * state.tauGlobal + (1 - alpha) * tauBlock;
end

end

