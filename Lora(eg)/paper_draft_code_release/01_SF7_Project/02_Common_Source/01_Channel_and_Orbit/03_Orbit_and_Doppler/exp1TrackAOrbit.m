function orbit = exp1TrackAOrbit(timeSec,config)
%EXP1TRACKAORBIT Frozen Track-A orbit with analytical Doppler rate.
% This preserves v4TrackAOrbit constants and sign conventions.

re = 6371e3;
height = 550e3;
mu = 3.986004418e14;
speedOfLightMps = 299792458;
a = re+height;
omega = sqrt(mu/a^3);
phase = omega*timeSec;
rangeM = sqrt(a^2+re^2-2*a*re*cos(phase));
rangeRateMps = a*re*omega.*sin(phase)./rangeM;
scale = config.carrierFrequencyHz*a*re*omega/speedOfLightMps;
dopplerHz = -scale.*sin(phase)./rangeM;
dopplerRateHzPerSec = -scale.*(omega*cos(phase)./rangeM- ...
    sin(phase).*rangeRateMps./rangeM.^2);
orbit = struct('timeSec',timeSec,'rangeM',rangeM, ...
    'dopplerHz',dopplerHz,'dopplerRateHzPerSec',dopplerRateHzPerSec, ...
    'omegaRadPerSec',omega,'speedOfLightMps',speedOfLightMps);
end

