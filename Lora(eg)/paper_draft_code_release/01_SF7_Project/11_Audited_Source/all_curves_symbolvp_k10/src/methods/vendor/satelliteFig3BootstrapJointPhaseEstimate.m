function estimate = satelliteFig3BootstrapJointPhaseEstimate( ...
        rxPilots,knownWaveformBins,config,coarseCfoBins)
%SATELLITEFIG3BOOTSTRAPJOINTPHASEESTIMATE Joint CFO/rate from pilot phase.
%   After removing the integer CFO, each complete known pilot supplies one
%   coherently averaged phase observation.  A quadratic phase fit across
%   the continuous eight-symbol preamble estimates residual CFO and rate.

arguments
    rxPilots (:,:) double
    knownWaveformBins (:,1) double
    config (1,1) struct
    coarseCfoBins (1,1) double
end

pilotCount = numel(knownWaveformBins);
m = config.samplesPerSymbol;
if size(rxPilots,1) ~= pilotCount || size(rxPilots,2) ~= m
    error('SatelliteFig3:JointBootstrapShape', ...
        'Pilot rows and known labels must describe complete symbols.');
end

coherent = complex(zeros(pilotCount,1));
for pilot = 1:pilotCount
    known = satelliteFig3ModulateSymbol(knownWaveformBins(pilot),config.sf);
    tone = rxPilots(pilot,:).*conj(known);
    globalSample = (pilot-1)*m+(0:m-1);
    coherent(pilot) = mean(tone.*exp( ...
        -1i*2*pi*coarseCfoBins*globalSample/m));
end

symbolCenter = (0:pilotCount-1).'+0.5;
unwrappedPhaseRad = unwrap(angle(coherent));
design = [ones(pilotCount,1),symbolCenter,0.5*symbolCenter.^2];
weight = abs(coherent).^2;
sqrtWeight = sqrt(max(weight,eps));
betaCycles = (design.*sqrtWeight)\ ...
    ((unwrappedPhaseRad/(2*pi)).*sqrtWeight);
rateBinsPerSymbol = betaCycles(3);
rateBinsPerSec = rateBinsPerSymbol/config.symbolDurationSec;
residualCenterCfoBins = betaCycles(2)+ ...
    rateBinsPerSymbol*symbolCenter;
centerCfoBins = coarseCfoBins+residualCenterCfoBins;

symbolStart = (0:pilotCount-1).';
startPhaseCycles = betaCycles(1)+betaCycles(2)*symbolStart+ ...
    0.5*rateBinsPerSymbol*symbolStart.^2;
startPhaseRad = angle(exp(1i*2*pi*startPhaseCycles));
fittedPhaseRad = 2*pi*(design*betaCycles);
phaseResidualRad = angle(exp(1i*( ...
    unwrappedPhaseRad-fittedPhaseRad)));

estimate = struct( ...
    'coarseCfoBins',coarseCfoBins, ...
    'centerCfoBins',centerCfoBins, ...
    'rateBinsPerSec',rateBinsPerSec, ...
    'startPhaseRad',startPhaseRad, ...
    'coherentPilotPhasor',coherent, ...
    'unwrappedPhaseRad',unwrappedPhaseRad, ...
    'phaseResidualRad',phaseResidualRad, ...
    'betaCycles',betaCycles, ...
    'symbolCenter',symbolCenter);
end
