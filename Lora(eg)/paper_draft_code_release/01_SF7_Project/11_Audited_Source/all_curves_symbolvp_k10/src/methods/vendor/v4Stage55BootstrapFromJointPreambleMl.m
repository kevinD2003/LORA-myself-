function bootstrap = v4Stage55BootstrapFromJointPreambleMl(common,estimate,c)
%V4STAGE55BOOTSTRAPFROMJOINTPREAMBLEML Build an unaliased phase model.
%
% Per-symbol phase unwrapping is ambiguous when the CFO changes by more
% than half a bin per symbol.  The sample-level joint ML estimate resolves
% that ambiguity, so its continuous polynomial phase is carried directly
% into the payload bootstrap state.

arguments
    common (1,1) struct
    estimate (1,1) struct
    c (1,1) struct
end

ratePerSymbol = estimate.rateBinsPerSec*c.symbolDurationSec;
phaseCycles0 = estimate.phaseAtFirstPreambleStartRad/(2*pi);
model = [phaseCycles0 estimate.cfoAtFirstPreambleStartBins ratePerSymbol];
starts = (0:c.bootstrapPilotCount-1).';
centers = starts+0.5;

bootstrap = common;
bootstrap.epsilonHatBins = estimate.cfoAtFirstPreambleStartBins;
bootstrap.coarseCfoBins = round(estimate.cfoAtFirstPreambleStartBins);
bootstrap.integerCfoBin = bootstrap.coarseCfoBins;
bootstrap.cfoBins = model(2)+model(3)*centers;
bootstrap.phaseRad = angle(exp(1i*2*pi*( ...
    model(1)+model(2)*starts+0.5*model(3)*starts.^2)));
bootstrap.rateBinsPerSec = estimate.rateBinsPerSec;
bootstrap.jointRateBinsPerSec = estimate.rateBinsPerSec;
bootstrap.phaseModelCycles = model;
bootstrap.joint.betaCycles = [model(1);0;model(3)];
bootstrap.joint.rateBinsPerSec = estimate.rateBinsPerSec;
bootstrap.joint.centerCfoBins = bootstrap.cfoBins;
bootstrap.joint.startPhaseRad = bootstrap.phaseRad;
bootstrap.source = 'sample-level joint known-preamble CFO/rate ML';
bootstrap.jointPreambleEstimate = estimate;
bootstrap.usesPayloadTruth = false;
bootstrap.usesOrbitTruth = false;
end
