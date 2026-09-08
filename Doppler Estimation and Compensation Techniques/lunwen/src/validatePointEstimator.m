function report = validatePointEstimator(cfg)
%VALIDATEPOINTESTIMATOR Verify +10 kHz CFO sign and native FFT resolution.

arguments
    cfg (1,1) struct
end

trueCfoHz = 10000;
sampleTimeS = (0:cfg.radio.samplesPerSymbol-1).'/ ...
    cfg.radio.sampleRateHz;
receivedDownchirp = loraPureDownchirp( ...
    cfg.radio.spreadingFactor).*exp(1j*2*pi*trueCfoHz*sampleTimeS);
estimateHz = estimateFromDownchirp(receivedDownchirp, cfg);
report.trueCfoHz = trueCfoHz;
report.estimatedCfoHz = estimateHz;
report.absoluteErrorHz = abs(estimateHz-trueCfoHz);
report.fftBinHz = cfg.radio.fftBinHz;
report.passed = estimateHz > 0 && ...
    report.absoluteErrorHz <= cfg.radio.fftBinHz;
end
