function bootstrap = senloraSymmetricV8BlendBootstrap( ...
        common,joint,rateGain,c)
%SENLORASYMMETRICV8BLENDBOOTSTRAP Blend complete Static/Dynamic phase paths.

arguments
    common (1,1) struct
    joint (1,1) struct
    rateGain (1,1) double {mustBeFinite,mustBeNonnegative}
    c (1,1) struct
end
if rateGain > 1
    error('EXP5V8:BlendGain','The phase-trajectory gain must not exceed one.');
end

xPayload = double(c.bootstrapPilotCount);
[staticPhaseAtPayload,staticCfoAtPayload] = ...
    v4BootstrapStateAtSymbol(common,xPayload,c);
staticModel = [staticPhaseAtPayload/(2*pi)- ...
    staticCfoAtPayload*xPayload, staticCfoAtPayload, 0];

dynamic = v4Stage55BootstrapFromJointPreambleMl(common,joint,c);
dynamicModel = dynamic.phaseModelCycles;
staticAnchor = localPhaseCycles(staticModel,xPayload);
dynamicAnchor = localPhaseCycles(dynamicModel,xPayload);
phaseAlignmentCycles = staticAnchor-dynamicAnchor;
dynamicModel(1) = dynamicModel(1)+phaseAlignmentCycles;

model = staticModel+rateGain*(dynamicModel-staticModel);
starts = (0:c.bootstrapPilotCount-1).';
centers = starts+0.5;
rateBinsPerSec = model(3)/c.symbolDurationSec;

bootstrap = common;
bootstrap.phaseModelCycles = model;
bootstrap.epsilonHatBins = model(2);
bootstrap.coarseCfoBins = round(model(2));
bootstrap.integerCfoBin = bootstrap.coarseCfoBins;
bootstrap.cfoBins = model(2)+model(3)*centers;
bootstrap.phaseRad = angle(exp(1i*2*pi*( ...
    model(1)+model(2)*starts+0.5*model(3)*starts.^2)));
bootstrap.rateBinsPerSec = rateBinsPerSec;
bootstrap.jointRateBinsPerSec = rateBinsPerSec;
if ~isfield(bootstrap,'joint')
    bootstrap.joint = struct();
end
bootstrap.joint.betaCycles = [model(1);0;model(3)];
bootstrap.joint.rateBinsPerSec = rateBinsPerSec;
bootstrap.joint.centerCfoBins = bootstrap.cfoBins;
bootstrap.joint.startPhaseRad = bootstrap.phaseRad;
bootstrap.jointPreambleEstimate = joint;
bootstrap.staticPhaseModelCycles = staticModel;
bootstrap.alignedDynamicPhaseModelCycles = dynamicModel;
bootstrap.phaseBlendGain = rateGain;
bootstrap.dynamicPhaseAlignmentCycles = phaseAlignmentCycles;
bootstrap.staticCfoAtPayloadBins = staticCfoAtPayload;
bootstrap.dynamicCfoAtPayloadBins = dynamicModel(2)+ ...
    dynamicModel(3)*(xPayload+0.5);
bootstrap.source = 'V8 payload-phase-aligned complete-trajectory blend';
bootstrap.usesPayloadTruth = false;
bootstrap.usesOrbitTruth = false;
end

function phaseCycles = localPhaseCycles(model,x)
phaseCycles = model(1)+model(2)*x+0.5*model(3)*x^2;
end
