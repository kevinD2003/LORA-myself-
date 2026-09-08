function dopplerHz = circularOrbitDoppler(timeS, cfg)
%CIRCULARORBITDOPPLER Zenith-pass model from references [50] and [51].
% This function re-derives the published equation; it does not copy the
% reference repository implementation.

arguments
    timeS double {mustBeFinite}
    cfg (1,1) struct
end

earthRadius = cfg.orbit.earthRadiusM;
orbitRadius = earthRadius + cfg.orbit.altitudeM;
omega = sqrt(cfg.orbit.gravitationalParameterM3S2/orbitRadius^3);
slantRangeM = sqrt(orbitRadius^2 + earthRadius^2 - ...
    2*orbitRadius*earthRadius*cos(omega*timeS));
normalizedDoppler = -(orbitRadius*earthRadius*omega/ ...
    cfg.orbit.speedOfLightMS).*sin(omega*timeS)./slantRangeM;
dopplerHz = cfg.radio.carrierFrequencyHz*normalizedDoppler;
end
