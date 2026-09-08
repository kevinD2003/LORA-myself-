function [result, history] = iterativeSoftDemodBlockFromFft(payloadFft, preambleFft, cfg)
%ITERATIVESOFTDEMODBLOCKFROMFFT Algorithm-2 style iterative wrapper.
%
% The SenLoRa paper refines h_hat through channelSense(confident symbols).
% That update is not fully specified in the paper. This wrapper preserves
% the control flow and convergence criterion while keeping payloadFft fixed.
% Replace the marked channel-update point when a concrete channel estimator
% is added for raw IQ samples.

arguments
    payloadFft (:,:) double
    preambleFft (:,:) double
    cfg struct
end

if ~isfield(cfg, "maxIter")
    cfg.maxIter = 5;
end

numIter = max(1, cfg.maxIter);
state = [];
previousMask = [];
history = struct([]);

for iterIdx = 1:numIter
    current = detectConfidentSymbolsFromFft(payloadFft, preambleFft, cfg, state);
    current.iteration = iterIdx;
    if isempty(history)
        history = current;
    else
        current = orderfields(current, history);
        history(iterIdx) = current;
    end

    if ~isempty(previousMask) && isequal(previousMask, current.confidentMask)
        history = history(1:iterIdx);
        result = current;
        result.converged = true;
        result.iterations = iterIdx;
        return;
    end

    previousMask = current.confidentMask;
    state = current.state;

    % channelSense(confidentSymbols, T, hHat) would update the demodulation
    % inputs here in a full raw-IQ receiver.
end

result = history(numIter);
result.converged = false;
result.iterations = numIter;

end
