function bootstrap = v3CommonBootstrap(rxPilots,config,options)
%V3COMMONBOOTSTRAP Shared receiver-visible eight-upchirp initialization.

arguments
    rxPilots (:,:) double
    config (1,1) struct
    options.SearchStepBins (1,1) double {mustBePositive} = 0.05
end

pilotCount = config.bootstrapPilotCount;
m = config.samplesPerSymbol;
if size(rxPilots,1) ~= pilotCount || size(rxPilots,2) ~= m
    error('V3:BootstrapShape','Exactly eight complete upchirps are required.');
end
knownPhysicalBins = zeros(pilotCount,1);
known = v3ModulateSymbol(0,config);
aggregatePower = zeros(1,m);
for pilot = 1:pilotCount
    aggregatePower = aggregatePower+abs(fft(rxPilots(pilot,:).*conj(known))).^2;
end
[~,coarseIndex] = max(aggregatePower);
coarseCfoBins = coarseIndex-1;
if coarseCfoBins >= m/2
    coarseCfoBins = coarseCfoBins-m;
end
candidates = (coarseCfoBins-1:options.SearchStepBins:coarseCfoBins+1).';
localCfoBins = zeros(pilotCount,1);
localPhaseRad = zeros(pilotCount,1);
peakRatio = zeros(pilotCount,1);
for pilot = 1:pilotCount
    local = v3PhaseRotationEstimate(rxPilots(pilot,:),0,config,candidates);
    localCfoBins(pilot) = local.offsetBins;
    localPhaseRad(pilot) = local.phaseRad;
    peakRatio(pilot) = local.peakRatio;
end
joint = v3BootstrapJointPhaseEstimate( ...
    rxPilots,knownPhysicalBins,config,coarseCfoBins);
[fittedCfoBins,localRateBinsPerSec,phaseModelCycles,startPhaseRad,fitDiagnostic] = ...
    localRobustBootstrapFit(localCfoBins,localPhaseRad,peakRatio,config, ...
    options.SearchStepBins);
bootstrap = struct('cfoBins',fittedCfoBins, ...
    'phaseRad',startPhaseRad,'rateBinsPerSec',localRateBinsPerSec, ...
    'coarseCfoBins',coarseCfoBins,'localCfoBins',localCfoBins, ...
    'localPhaseRad',localPhaseRad,'peakRatio',peakRatio, ...
    'phaseModelCycles',phaseModelCycles,'localFit',fitDiagnostic, ...
    'joint',joint,'jointRateBinsPerSec',joint.rateBinsPerSec, ...
    'aggregatePower',aggregatePower, ...
    'source','common 8-upchirp receiver-visible bootstrap', ...
    'usesPayloadTruth',false,'usesOrbitTruth',false);
end

function [fittedCfo,rate,phaseModel,startPhase,diagnostic] = ...
        localRobustBootstrapFit(localCfo,localPhase,peakRatio,config,searchStep)
count = numel(localCfo);
centerTime = ((0:count-1).'+0.5)*config.symbolDurationSec;
design = [ones(count,1),centerTime];
baseWeight = min(4,max(1,peakRatio(:)));
weight = baseWeight;
beta = localWeightedFit(design,localCfo(:),weight);
huber = max(4*searchStep,0.05);
for iteration = 1:2
    residual = localCfo(:)-design*beta;
    weight = baseWeight.*min(1,huber./max(abs(residual),eps));
    beta = localWeightedFit(design,localCfo(:),weight);
end
fittedCfo = design*beta;
rate = beta(2);

startIndex = (0:count-1).';
unwrappedPhase = zeros(count,1);
unwrappedPhase(1) = localPhase(1);
for index = 2:count
    expectedAdvance = 2*pi*(fittedCfo(index-1)+fittedCfo(index))/2;
    observedAdvance = angle(exp(1i*(localPhase(index)-localPhase(index-1))));
    unwrappedPhase(index) = unwrappedPhase(index-1)+observedAdvance+ ...
        2*pi*round((expectedAdvance-observedAdvance)/(2*pi));
end
ratePerSymbol = rate*config.symbolDurationSec;
adjustedCycles = unwrappedPhase/(2*pi)-0.5*ratePerSymbol*startIndex.^2;
phaseLinear = [ones(count,1),startIndex]\adjustedCycles;
phaseModel = [phaseLinear(1);phaseLinear(2);ratePerSymbol];
phaseCycles = phaseModel(1)+phaseModel(2)*startIndex+ ...
    0.5*phaseModel(3)*startIndex.^2;
startPhase = angle(exp(1i*2*pi*phaseCycles));
diagnostic = struct('centerTimeSec',centerTime,'robustWeight',weight, ...
    'fitResidualBins',localCfo(:)-fittedCfo, ...
    'rateBinsPerSec',rate,'phaseModelCycles',phaseModel, ...
    'jointPhaseRateBinsPerSec',NaN);
end

function beta = localWeightedFit(design,response,weight)
sqrtWeight = sqrt(max(weight,eps));
beta = (design.*sqrtWeight)\(response.*sqrtWeight);
end
