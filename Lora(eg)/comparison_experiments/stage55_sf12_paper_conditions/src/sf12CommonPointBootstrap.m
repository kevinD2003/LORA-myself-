function bootstrap = sf12CommonPointBootstrap(rxInitialDownchirp,cfg)
%SF12COMMONPOINTBOOTSTRAP Paper Point estimate from last full downchirp.
% RXINITIALDOWNCHIRP is already represented after multiplication by the
% pure upchirp, so its FFT peak is the common initial CFO observation.

bootstrap.cfoHz = sf12EstimateSignedFftFrequency( ...
    rxInitialDownchirp,cfg.radio.sampleRateHz, ...
    cfg.radio.samplesPerSymbol);
bootstrap.phaseRad = angle(sum(rxInitialDownchirp(:).*exp(-1j*2*pi* ...
    bootstrap.cfoHz*(0:numel(rxInitialDownchirp)-1).'/ ...
    cfg.radio.sampleRateHz)));
bootstrap.source = "last-complete-sync-downchirp Point FFT";
bootstrap.usesPayloadTruth = false;
bootstrap.usesOrbitTruth = false;
end
