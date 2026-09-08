function landmarks = dopplerLandmarks(cfg)
%DOPPLERLANDMARKS Compute non-negotiable checks for the orbital model.

arguments
    cfg (1,1) struct
end

earthRadius = cfg.orbit.earthRadiusM;
orbitRadius = earthRadius + cfg.orbit.altitudeM;
omega = sqrt(cfg.orbit.gravitationalParameterM3S2/orbitRadius^3);
landmarks.visibilityHalfTimeS = acos(earthRadius/orbitRadius)/omega;
landmarks.fdAtMinus366Hz = circularOrbitDoppler(-366, cfg);
landmarks.fdAtZeroHz = circularOrbitDoppler(0, cfg);
stepS = 1e-3;
landmarks.rateAtZeroHzS = ( ...
    circularOrbitDoppler(stepS, cfg) - ...
    circularOrbitDoppler(-stepS, cfg))/(2*stepS);
end
