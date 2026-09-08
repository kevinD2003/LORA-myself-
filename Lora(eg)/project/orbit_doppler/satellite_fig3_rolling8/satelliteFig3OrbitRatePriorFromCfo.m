function prior = satelliteFig3OrbitRatePriorFromCfo(cfoBins,config)
%SATELLITEFIG3ORBITRATEPRIORFROMCFO Receiver-visible orbit rate prior.
%   The Figure-3 orbit and carrier are configured receiver knowledge.  The
%   Doppler shift is monotone over the single pass, so a coarse preamble
%   CFO uniquely identifies the corresponding broad Doppler-rate region.
%   No payload label, simulated start time, or channel truth is accepted.

arguments
    cfoBins (1,1) double {mustBeFinite}
    config (1,1) struct
end

[window,~] = satelliteFig3VisibilityWindow(config);
timeGrid = linspace(-window.deltaTimeOutSec, ...
    window.deltaTimeOutSec,20001).';
trajectory = satelliteFig3Trajectory(timeGrid,config);
shiftBins = trajectory.dopplerShiftHz/config.fftBinSpacingHz;
% INTERP1 requires increasing abscissae; Figure-3 Doppler decreases with
% time across this interval.
estimatedTime = interp1(flipud(shiftBins),flipud(timeGrid),cfoBins, ...
    'linear','extrap');
estimatedTime = min(window.deltaTimeOutSec,max( ...
    -window.deltaTimeOutSec,estimatedTime));
point = satelliteFig3Trajectory(estimatedTime,config);
prior = struct( ...
    'coarseCfoBins',cfoBins, ...
    'estimatedOrbitTimeSec',estimatedTime, ...
    'rateBinsPerSec',point.dopplerRateHzPerSec/config.fftBinSpacingHz);
end
