function dopplerHz = sf12CircularOrbitDoppler(timeSec,cfg)
%SF12CIRCULARORBITDOPPLER Circular zenith-pass Doppler model.

if cfg.orbit.disableDoppler
    dopplerHz = zeros(size(timeSec));
    return
end
re = cfg.orbit.earthRadiusM;
ro = re+cfg.orbit.altitudeM;
omega = sqrt(cfg.orbit.gravitationalParameterM3S2/ro^3);
range = sqrt(ro^2+re^2-2*ro*re*cos(omega*timeSec));
normalized = -(ro*re*omega/cfg.orbit.speedOfLightMps).* ...
    sin(omega*timeSec)./range;
dopplerHz = cfg.radio.carrierFrequencyHz*normalized;
end
