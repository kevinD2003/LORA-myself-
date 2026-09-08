function [cfoBins, dopplerHz, symbolTimeSeconds, rateProfile] = ...
    buildDopplerCfoTrajectory(numSymbols, sf, bandwidthHz, ...
    initialDopplerHz, dopplerRateHzPerSecond)
%BUILDDOPPLERCFOTRAJECTORY Integrate a Doppler-rate profile at symbol times.
%
% dopplerRateHzPerSecond can be a scalar or one value per LoRa symbol.
% cfoBins is normalized by the FFT-bin spacing BW/2^SF and can be passed
% directly to generateDopplerLoRaSymbols. The receiver does not use this
% trajectory; it is only the controlled channel impairment.

arguments
    numSymbols (1,1) double {mustBeInteger, mustBePositive}
    sf (1,1) double {mustBeInteger, mustBePositive}
    bandwidthHz (1,1) double {mustBePositive}
    initialDopplerHz (1,1) double
    dopplerRateHzPerSecond (:,1) double
end

if isscalar(dopplerRateHzPerSecond)
    rateProfile = repmat(dopplerRateHzPerSecond, numSymbols, 1);
elseif numel(dopplerRateHzPerSecond) == numSymbols
    rateProfile = dopplerRateHzPerSecond;
else
    error("SenLoRa:DopplerRateLengthMismatch", ...
        "Doppler rate must be scalar or contain one value per symbol.");
end

symbolDuration = 2 ^ sf / bandwidthHz;
symbolTimeSeconds = (0:(numSymbols - 1)).' * symbolDuration;
dopplerHz = initialDopplerHz + ...
    cumtrapz(symbolTimeSeconds, rateProfile);
binSpacingHz = bandwidthHz / (2 ^ sf);
cfoBins = dopplerHz / binSpacingHz;

end
