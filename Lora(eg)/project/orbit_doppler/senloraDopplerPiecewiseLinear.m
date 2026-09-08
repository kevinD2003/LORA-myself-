function result = senloraDopplerPiecewiseLinear(symbol, sf, startTimeSec, config, options)
%SENLORADOPPLERPIECEWISELINEAR Port of the reference paper's Eq. (18)-(20).

arguments
    symbol (1,1) double {mustBeInteger, mustBeNonnegative}
    sf (1,1) double {mustBeInteger, mustBePositive}
    startTimeSec (1,1) double
    config (1,1) struct
    options.BandwidthHz (1,1) double = 250e3
end

m = 2^sf;
if symbol >= m || ~isfinite(startTimeSec)
    error("SenLoRa:InvalidDopplerSymbol", "Invalid symbol or start time.");
end
sampleIndex = (0:m-1).';
timeWithinSymbol = sampleIndex/options.BandwidthHz;
sampleTime = startTimeSec+timeWithinSymbol;
basebandHz = options.BandwidthHz*(mod(sampleIndex+symbol,m)/m-0.5);
orbit = senloraOrbitDopplerTrajectory(sampleTime, config);
exactHz = -(config.carrierFrequencyHz+basebandHz).* ...
    orbit.radialVelocityMps/config.speedOfLightMps;

wrapIndex = m-symbol+1;
if symbol == 0
    wrapIndex = m+1;
    slopeIndices = [1 2];
elseif m-wrapIndex+1 >= wrapIndex-1 && m-wrapIndex+1 >= 2
    slopeIndices = [wrapIndex min(wrapIndex+1,m)];
else
    slopeIndices = [max(1,wrapIndex-2) wrapIndex-1];
end
cdHzPerSec = (exactHz(slopeIndices(2))-exactHz(slopeIndices(1)))*options.BandwidthHz;
vdHz = exactHz(1);
linearHz = vdHz+cdHzPerSec*timeWithinSymbol;
if wrapIndex <= m
    wrapTime = startTimeSec+(wrapIndex-1)/options.BandwidthHz;
    wrapOrbit = senloraOrbitDopplerTrajectory(wrapTime, config);
    deltaFkHz = -options.BandwidthHz*wrapOrbit.radialVelocityMps/config.speedOfLightMps;
    linearHz(wrapIndex:end) = linearHz(wrapIndex:end)-deltaFkHz;
else
    deltaFkHz = 0;
end

exactPhase = integrateFrequency(exactHz, options.BandwidthHz);
linearPhase = integrateFrequency(linearHz, options.BandwidthHz);
result = struct( ...
    "symbol", symbol, "sf", sf, "sampleIndex", sampleIndex, ...
    "sampleTimeSec", sampleTime, "basebandFrequencyHz", basebandHz, ...
    "exactDopplerHz", exactHz, "linearDopplerHz", linearHz, ...
    "exactPhaseRad", exactPhase, "linearPhaseRad", linearPhase, ...
    "dopplerErrorHz", linearHz-exactHz, ...
    "phaseErrorRad", linearPhase-exactPhase, ...
    "wrapIndex", wrapIndex, "slopeSampleIndices", slopeIndices, ...
    "vdHz", vdHz, "cdHzPerSec", cdHzPerSec, ...
    "appliedDeltaFkHz", deltaFkHz, ...
    "meanAbsErrorHz", mean(abs(linearHz-exactHz)), ...
    "maxAbsErrorHz", max(abs(linearHz-exactHz)), ...
    "phaseRmseRad", sqrt(mean((linearPhase-exactPhase).^2)));
end

function phaseRad = integrateFrequency(frequencyHz, sampleRateHz)
phaseIncrement = pi/sampleRateHz*(frequencyHz(1:end-1)+frequencyHz(2:end));
phaseRad = [0; cumsum(phaseIncrement)];
end
