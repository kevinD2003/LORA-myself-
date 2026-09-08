function config = lora_orbit_doppler_config()
%LORA_ORBIT_DOPPLER_CONFIG Configure the paper Figure 3 reproduction.
%   CONFIG = LORA_ORBIT_DOPPLER_CONFIG() returns the physical constants,
%   orbit parameters, visibility limits, sampling settings, and paper
%   reference values used by the dynamic Doppler trajectory.
%
%   All angles used by the numerical model are stored in radians.

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

config.plotHalfSpanSec = 400;
config.timeStepSec = 0.25;
config.figurePosition = [100, 100, 1050, 620];

config.paperReportedApproximateValue = struct( ...
    "visibleDurationSec", 422, ...
    "dopplerShiftAbsRangeHz", [7.6e3, 18.2e3], ...
    "dopplerRateAbsRangeHzPerSec", [8.3, 165.1]);

config.paperParameterDegrees = struct( ...
    "inclination", 15, ...
    "theoreticalMaxElevation", 56, ...
    "minimumElevation", 10, ...
    "maximumElevation", 50);
end
