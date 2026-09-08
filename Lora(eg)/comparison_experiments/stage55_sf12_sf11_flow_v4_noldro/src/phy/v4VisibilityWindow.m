function [window,isVisible] = v4VisibilityWindow(config,timeSec)
%V4VISIBILITYWINDOW Two-lobe communication window and central blind area.

arguments
    config (1,1) struct
    timeSec double = []
end
rs = config.earthRadiusM+config.orbitHeightM;
omegaS = sqrt(config.gravityMps2*config.earthRadiusM^2/rs^3);
omegaF = omegaS-config.earthRotationRadPerSec*cos(config.inclinationRad);
gamma = @(theta) acos(config.earthRadiusM/rs*cos(theta))-theta;
gammaC = gamma(config.theoreticalMaxElevationRad);
gammaMin = gamma(config.minimumElevationRad);
gammaMax = gamma(config.maximumElevationRad);
deltaOut = abs(acos(min(1,max(-1,cos(gammaMin)/cos(gammaC))))/omegaF);
deltaIn = abs(acos(min(1,max(-1,cos(gammaMax)/cos(gammaC))))/omegaF);
center = config.centralVisibilityTimeSec;
window = struct('deltaTimeOutSec',deltaOut,'deltaTimeInSec',deltaIn, ...
    'intervalsSec',[center-deltaOut,center-deltaIn; ...
    center+deltaIn,center+deltaOut], ...
    'blindIntervalSec',[center-deltaIn,center+deltaIn], ...
    'totalVisibleDurationSec',2*(deltaOut-deltaIn));
offset = abs(timeSec-center);
isVisible = offset >= deltaIn & offset <= deltaOut;
end

