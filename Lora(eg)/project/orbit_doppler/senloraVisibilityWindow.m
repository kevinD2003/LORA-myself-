function [window, isVisible] = senloraVisibilityWindow(config, timeSec)
%SENLORAVISIBILITYWINDOW Visibility intervals used by the reference model.

arguments
    config (1, 1) struct
    timeSec double = []
end

orbitRadiusM = config.earthRadiusM + config.orbitHeightM;
omegaSatellite = sqrt(config.gravityMps2*config.earthRadiusM^2/orbitRadiusM^3);
omegaFixed = omegaSatellite - ...
    config.earthRotationRadPerSec*cos(config.inclinationRad);

gammaCentral = elevationToCentral(config.theoreticalMaxElevationRad, config);
gammaMinimum = elevationToCentral(config.minimumElevationRad, config);
gammaMaximum = elevationToCentral(config.maximumElevationRad, config);

deltaOutSec = boundaryTime(gammaMinimum, gammaCentral, omegaFixed);
deltaInSec = boundaryTime(gammaMaximum, gammaCentral, omegaFixed);
centralTimeSec = config.centralVisibilityTimeSec;

window = struct( ...
    "omegaSatelliteRadPerSec", omegaSatellite, ...
    "omegaFixedRadPerSec", omegaFixed, ...
    "gammaCentralRad", gammaCentral, ...
    "gammaMinimumRad", gammaMinimum, ...
    "gammaMaximumRad", gammaMaximum, ...
    "deltaTimeOutSec", deltaOutSec, ...
    "deltaTimeInSec", deltaInSec, ...
    "intervalsSec", [ ...
        centralTimeSec-deltaOutSec, centralTimeSec-deltaInSec; ...
        centralTimeSec+deltaInSec, centralTimeSec+deltaOutSec], ...
    "blindIntervalSec", [ ...
        centralTimeSec-deltaInSec, centralTimeSec+deltaInSec], ...
    "totalVisibleDurationSec", 2*(deltaOutSec-deltaInSec));

offsetSec = abs(timeSec-centralTimeSec);
isVisible = (offsetSec >= deltaInSec) & (offsetSec <= deltaOutSec);
end

function gammaRad = elevationToCentral(elevationRad, config)
radiusRatio = config.earthRadiusM/(config.earthRadiusM+config.orbitHeightM);
gammaRad = acos(radiusRatio*cos(elevationRad))-elevationRad;
end

function deltaSec = boundaryTime(gammaRad, gammaCentral, omegaFixed)
argument = cos(gammaRad)/cos(gammaCentral);
argument = min(1, max(-1, argument));
deltaSec = abs(acos(argument)/omegaFixed);
end
