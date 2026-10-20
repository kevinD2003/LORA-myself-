function orbit = v4TrackAOrbit(timeSec,config)
%V4TRACKAORBIT Independent zenith circular-orbit model for Track A.
re = 6371e3; height = 550e3; mu = 3.986004418e14; c = 299792458;
a = re+height;
omega = sqrt(mu/a^3);
range = sqrt(a^2+re^2-2*a*re*cos(omega*timeSec));
dopplerHz = -config.carrierFrequencyHz*a*re*omega.*sin(omega*timeSec)./(c*range);
orbit = struct('timeSec',timeSec,'rangeM',range,'dopplerHz',dopplerHz, ...
    'omegaRadPerSec',omega,'speedOfLightMps',c);
end
