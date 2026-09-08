function [window, isVisible] = satelliteFig3VisibilityWindow(config, timeSec)
%SATELLITEFIG3VISIBILITYWINDOW Figure 3 two-lobe single-device window.

arguments
    config (1,1) struct
    timeSec double = []
end

if ~(config.minimumElevationRad >= 0 && ...
        config.minimumElevationRad < config.maximumElevationRad && ...
        config.maximumElevationRad < config.theoreticalMaxElevationRad)
    error('SatelliteFig3:InvalidElevationLimits', ...
        'Expected 0 <= thetaMin < thetaMax < thetaC.');
end

rs = config.earthRadiusM + config.orbitHeightM;
omegaS = sqrt(config.gravityMps2*config.earthRadiusM^2/rs^3);
omegaF = omegaS - config.earthRotationRadPerSec*cos(config.inclinationRad);
gamma = @(theta) acos(config.earthRadiusM/rs*cos(theta)) - theta;
gammaC = gamma(config.theoreticalMaxElevationRad);
gammaMin = gamma(config.minimumElevationRad);
gammaMax = gamma(config.maximumElevationRad);
deltaOut = abs(acos(min(1,max(-1,cos(gammaMin)/cos(gammaC))))/omegaF);
deltaIn = abs(acos(min(1,max(-1,cos(gammaMax)/cos(gammaC))))/omegaF);
tc = config.centralVisibilityTimeSec;
window = struct( ...
    'deltaTimeOutSec', deltaOut, ...
    'deltaTimeInSec', deltaIn, ...
    'intervalsSec', [tc-deltaOut, tc-deltaIn; tc+deltaIn, tc+deltaOut], ...
    'blindIntervalSec', [tc-deltaIn, tc+deltaIn], ...
    'totalVisibleDurationSec', 2*(deltaOut-deltaIn), ...
    'omegaSatelliteRadPerSec', omegaS, ...
    'omegaFixedRadPerSec', omegaF, ...
    'gammaCentralRad', gammaC);

offset = abs(timeSec - tc);
isVisible = offset >= deltaIn & offset <= deltaOut;
end
