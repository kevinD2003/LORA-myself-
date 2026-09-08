function template = integratedDopplerTemplate( ...
    orbitStartS, localChirpStartS, cfg)
%INTEGRATEDDOPPLERTEMPLATE Apply time-varying Doppler through phase integral.
% A constant phase from earlier chirps is immaterial to FFT peak detection,
% so integration starts locally while using the exact orbital time samples.

arguments
    orbitStartS (1,1) double {mustBeFinite}
    localChirpStartS (1,1) double {mustBeFinite}
    cfg (1,1) struct
end

numSamples = cfg.radio.samplesPerSymbol;
sampleRateHz = cfg.radio.sampleRateHz;
relativeTimeS = (0:numSamples-1).'/sampleRateHz;
frameTimeS = localChirpStartS + relativeTimeS;
frequencyHz = circularOrbitDoppler( ...
    orbitStartS + cfg.orbit.frameDopplerTimeScale*frameTimeS, cfg);
phaseRad = 2*pi*cumsum(frequencyHz)/sampleRateHz;
template = exp(1j*phaseRad);
end
