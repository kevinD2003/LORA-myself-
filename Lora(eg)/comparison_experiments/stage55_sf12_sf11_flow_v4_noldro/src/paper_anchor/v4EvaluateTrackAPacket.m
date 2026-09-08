function metrics = v4EvaluateTrackAPacket(receiver,truth,config)
%V4EVALUATETRACKAPACKET Truth-only Track A scorer; never passed to receiver.
errors = receiver.detectedPhysicalBins ~= truth.labels;
cfoErrorBins = receiver.estimatedCfoBins-truth.dataCfoHz/config.fftBinSpacingHz;
accepted = false(23,1);
falseAccepted = false(23,1);
if isfield(receiver,'virtualPilotAccepted')
    accepted = receiver.virtualPilotAccepted;
    falseAccepted = accepted & errors;
end
metrics = struct('symbolErrors',sum(errors),'symbolCount',23,'ser',mean(errors), ...
    'cfoSquaredErrorBins',sum(cfoErrorBins.^2),'cfoRmseBins',sqrt(mean(cfoErrorBins.^2)), ...
    'cfoSquaredErrorHz',sum((cfoErrorBins*config.fftBinSpacingHz).^2), ...
    'cfoRmseHz',sqrt(mean((cfoErrorBins*config.fftBinSpacingHz).^2)), ...
    'vpAccepted',sum(accepted),'vpFalseAccepted',sum(falseAccepted));
end
