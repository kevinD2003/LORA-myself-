function result = satelliteFig3PiecewiseDoppler(symbol, startTimeSec, config)
%SATELLITEFIG3PIECEWISEDOPPLER Exact full-RF Doppler and Eq. (18)-(20) proxy.
%   The exact curve is for the channel.  The piecewise-linear curve is kept
%   solely as a receiver/validation approximation, avoiding inverse crime.

m = config.samplesPerSymbol;
fs = config.sampleRateHz;
n = (0:m-1).';
t = startTimeSec + n/fs;
basebandHz = satelliteFig3SymbolFrequency(symbol, config.sf, config.bandwidthHz);
orbit = satelliteFig3Trajectory(t, config);
exactHz = -(config.carrierFrequencyHz + basebandHz).* ...
    orbit.radialVelocityMps/config.speedOfLightMps;
[wrapIndex, slopeIndices] = localSlopeSamples(symbol, m);
slopeHzPerSec = (exactHz(slopeIndices(2))-exactHz(slopeIndices(1)))*fs;
linearHz = exactHz(1) + slopeHzPerSec*n/fs;
if wrapIndex <= m
    wrapOrbit = satelliteFig3Trajectory(t(wrapIndex), config);
    wrapCorrectionHz = config.bandwidthHz*wrapOrbit.radialVelocityMps/ ...
        config.speedOfLightMps;
    linearHz(wrapIndex:end) = linearHz(wrapIndex:end) + wrapCorrectionHz;
else
    wrapCorrectionHz = 0;
end
exactPhase = localIntegrate(exactHz, fs);
linearPhase = localIntegrate(linearHz, fs);
result = struct( ...
    'sampleTimeSec', t, 'basebandFrequencyHz', basebandHz, ...
    'exactDopplerHz', exactHz, 'linearDopplerHz', linearHz, ...
    'exactPhaseRad', exactPhase, 'linearPhaseRad', linearPhase, ...
    'dopplerErrorHz', linearHz-exactHz, ...
    'phaseErrorRad', linearPhase-exactPhase, ...
    'slopeHzPerSec', slopeHzPerSec, 'wrapIndex', wrapIndex, ...
    'wrapCorrectionHz', wrapCorrectionHz, ...
    'meanAbsErrorHz', mean(abs(linearHz-exactHz)), ...
    'phaseRmseRad', sqrt(mean((linearPhase-exactPhase).^2)));
end

function [wrapIndex, slopeIndices] = localSlopeSamples(symbol, m)
if symbol == 0
    wrapIndex = m + 1;
    slopeIndices = [1, 2];
    return
end
wrapIndex = m - double(symbol) + 1;
preCount = wrapIndex - 1;
postCount = m - wrapIndex + 1;
if postCount >= preCount && postCount >= 2
    slopeIndices = [wrapIndex, wrapIndex+1];
elseif preCount >= 2
    slopeIndices = [wrapIndex-2, wrapIndex-1];
else
    slopeIndices = [wrapIndex, wrapIndex+1];
end
end

function phase = localIntegrate(frequencyHz, fs)
phase = [0; cumsum(pi/fs*(frequencyHz(1:end-1)+frequencyHz(2:end)))];
end
