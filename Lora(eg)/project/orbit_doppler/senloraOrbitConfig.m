function config = senloraOrbitConfig()
%SENLORAORBITCONFIG Physical constants from the lora(CFO) reference model.
%
% Angles are stored in radians. The configuration mirrors the reference
% orbit model: a 550-km circular LEO and an 868-MHz carrier.

config.speedOfLightMps = 3e8;
config.gravityMps2 = 9.8;
config.earthRadiusM = 6371e3;
config.earthRotationRadPerSec = 7.292e-5;
config.orbitHeightM = 550e3;
config.inclinationRad = deg2rad(15);
config.carrierFrequencyHz = 868e6;
config.theoreticalMaxElevationRad = deg2rad(56);
config.minimumElevationRad = deg2rad(10);
config.maximumElevationRad = deg2rad(50);
config.centralVisibilityTimeSec = 0;
config.internalAngleUnit = "radian";
end
