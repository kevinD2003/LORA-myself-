function trajectory = v4Trajectory(timeSec,config)
%V4TRAJECTORY Exact circular-orbit single-device trajectory from SF11.

if any(~isfinite(timeSec),'all')
    error('V4:InvalidTime','Trajectory time must be finite.');
end
shape = size(timeSec);
t = timeSec(:);
rs = config.earthRadiusM+config.orbitHeightM;
omegaS = sqrt(config.gravityMps2*config.earthRadiusM^2/rs^3);
omegaF = omegaS-config.earthRotationRadPerSec*cos(config.inclinationRad);
rho = config.earthRadiusM/rs;
gammaC = acos(rho*cos(config.theoreticalMaxElevationRad))- ...
    config.theoreticalMaxElevationRad;
phase = omegaF*(t-config.centralVisibilityTimeSec);
cosGamma = min(1,max(-1,cos(gammaC).*cos(phase)));
gamma = acos(cosGamma);
rangeM = sqrt(rs^2+config.earthRadiusM^2- ...
    2*config.earthRadiusM*rs.*cosGamma);
velocityScale = config.earthRadiusM*rs*cos(gammaC)*omegaF;
radialVelocity = velocityScale*sin(phase)./rangeM;
radialAcceleration = velocityScale*(omegaF*cos(phase)./rangeM- ...
    sin(phase).*radialVelocity./rangeM.^2);
doppler = -config.carrierFrequencyHz*radialVelocity/config.speedOfLightMps;
dopplerRate = -config.carrierFrequencyHz*radialAcceleration/config.speedOfLightMps;
elevation = atan2(rs*cosGamma-config.earthRadiusM,rs*sin(gamma));
trajectory = struct('timeSec',reshape(t,shape), ...
    'elevationRad',reshape(elevation,shape), ...
    'slantRangeM',reshape(rangeM,shape), ...
    'radialVelocityMps',reshape(radialVelocity,shape), ...
    'radialAccelerationMps2',reshape(radialAcceleration,shape), ...
    'dopplerShiftHz',reshape(doppler,shape), ...
    'dopplerRateHzPerSec',reshape(dopplerRate,shape), ...
    'omegaSatelliteRadPerSec',omegaS,'omegaFixedRadPerSec',omegaF);
end

