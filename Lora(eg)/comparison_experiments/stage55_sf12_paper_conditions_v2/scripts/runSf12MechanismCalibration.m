function manifest = runSf12MechanismCalibration(options)
%RUNSF12MECHANISMCALIBRATION Measure SF12 CFO scale and freeze manifest.

arguments
    options.PacketCount (1,1) double {mustBeInteger,mustBePositive} = 100
    options.SnrDb (1,1) double = -21
    options.ValidationPacketsPerCase (1,1) double ...
        {mustBeInteger,mustBePositive} = 100
    options.MinimumAcceptanceRate (1,1) double ...
        {mustBeNonnegative,mustBeLessThanOrEqual( ...
        options.MinimumAcceptanceRate,1)} = 0.5
    options.MaximumFalseAcceptanceRate (1,1) double ...
        {mustBeNonnegative,mustBeLessThanOrEqual( ...
        options.MaximumFalseAcceptanceRate,1)} = 0.1
end
root = sf12SetupPaths();
cfg = sf12PaperCommonConfig();
offsetBins = (0:0.05:2).';
errors = zeros(numel(offsetBins),options.PacketCount);
boundaryHits = false(size(errors));
n = cfg.radio.samplesPerSymbol;
sample = 0:n-1;
oldRng = rng;
cleanup = onCleanup(@()rng(oldRng));
for i = 1:numel(offsetBins)
    for packet = 1:options.PacketCount
        rng(cfg.seeds.calibrationNoiseBase+i*10000+packet,'twister');
        tone = exp(1j*2*pi*offsetBins(i)*sample/n);
        noisePower = 10^(-options.SnrDb/10);
        rx = tone+sqrt(noisePower/2)*(randn(1,n)+1j*randn(1,n));
        localCfg = cfg;
        localCfg.receiver.residualSearchHalfWidthBins = 2.05;
        estimate = sf12EstimateResidualCfo(rx,0,localCfg);
        errors(i,packet) = estimate.offsetBins-offsetBins(i);
        boundaryHits(i,packet) = estimate.atBoundary;
    end
end
absoluteErrorsHz = abs(errors(:))*cfg.radio.fftBinHz;
sorted = sort(absoluteErrorsHz);
q95 = sorted(max(1,ceil(0.95*numel(sorted))));
stdHz = std(errors(:)*cfg.radio.fftBinHz);
manifest = cfg.receiver.manifest;
manifest.schemaVersion = 2;
manifest.receiverName = 'Stage55-VP-quality-SER-v2';
manifest.source = ...
    'pre-registered SF12 physics-gated V2 mechanism-calibration protocol';
manifest.measurements = struct();
manifest.calibrationRunCompleted = true;
manifest.status = 'frozen_after_mechanism_calibration';
manifest.calibrationTimestamp = char(datetime('now','Format','yyyy-MM-dd HH:mm:ss'));
manifest.calibrationPacketCountPerOffset = options.PacketCount;
manifest.calibrationSnrDb = options.SnrDb;
manifest.scanOffsetBins = offsetBins.';
manifest.measurements.singleSymbolCfoStdHz = stdHz;
manifest.measurements.absoluteCfoError95Hz = q95;
manifest.measurements.stdCoverage1 = mean(absoluteErrorsHz <= stdHz);
manifest.measurements.stdCoverage2 = mean(absoluteErrorsHz <= 2*stdHz);
manifest.measurements.searchBoundaryHitRate = mean(boundaryHits(:));
manifest.measurements.phaseWholeCycleAmbiguityRate = ...
    mean(absoluteErrorsHz*cfg.radio.symbolDurationSec >= 0.5);

% Freeze the final innovation gate before validating virtual pilots.  The
% gate covers the receiver's maximum admitted rate across the largest data
% gap in the common frame, two independent 95-percent measurement-error
% allowances, and one fine-search grid step.  It remains strictly inside
% the half-symbol residual search boundary.
layout = sf12BuildFrameLayout(cfg);
maximumDataGapSec = max(diff(layout.dataStartTimeSec));
gridStepHz = cfg.receiver.residualSearchStepBins*cfg.radio.fftBinHz;
usableSearchHalfWidthHz = ...
    cfg.receiver.residualSearchHalfWidthBins*cfg.radio.fftBinHz-gridStepHz;
rateBudgetHz = cfg.receiver.maximumRateHzPerSec*maximumDataGapSec;
measurementBudgetHz = 2*q95;
derivedInnovationLimitHz = rateBudgetHz+measurementBudgetHz+gridStepHz;
finalInnovationLimitHz = min(usableSearchHalfWidthHz, ...
    derivedInnovationLimitHz);
assert(finalInnovationLimitHz > 0 && ...
    finalInnovationLimitHz < ...
    cfg.receiver.residualSearchHalfWidthBins*cfg.radio.fftBinHz);
manifest.parameters.singleSymbolCfoStdHz = stdHz;
manifest.parameters.innovationLimitHz = finalInnovationLimitHz;

finalCfg = cfg;
finalCfg.receiver.singleSymbolCfoStdHz = stdHz;
finalCfg.receiver.innovationLimitHz = finalInnovationLimitHz;
finalCfg.receiver.manifest = manifest;
validationCases = ["case1","case2"];
acceptedCount = zeros(size(validationCases));
falseAcceptedCount = zeros(size(validationCases));
symbolErrorCount = zeros(size(validationCases));
for caseIndex = 1:numel(validationCases)
    for packet = 1:options.ValidationPacketsPerCase
        paired = sf12PairedFrameSimulation(finalCfg, ...
            validationCases(caseIndex),options.SnrDb,packet, ...
            "calibration",1);
        acceptedCount(caseIndex) = acceptedCount(caseIndex)+ ...
            paired.stage55AcceptedVirtualPilots;
        falseAcceptedCount(caseIndex) = falseAcceptedCount(caseIndex)+ ...
            paired.stage55FalseAcceptedVirtualPilots;
        symbolErrorCount(caseIndex) = symbolErrorCount(caseIndex)+ ...
            paired.stage55SymbolErrors;
    end
end
candidateCount = options.ValidationPacketsPerCase* ...
    cfg.frame.payloadSymbolCount;
acceptanceRate = acceptedCount/candidateCount;
falseAcceptanceRate = falseAcceptedCount./max(acceptedCount,1);
validationPassed = all(acceptanceRate >= options.MinimumAcceptanceRate) && ...
    all(falseAcceptanceRate <= options.MaximumFalseAcceptanceRate);
assert(validationPassed, ...
    ['Final Stage55 parameters failed independent Case1/Case2 mechanism ' ...
    'validation.']);

manifest.measurements.validationCases = cellstr(validationCases);
manifest.measurements.validationPacketsPerCase = ...
    options.ValidationPacketsPerCase;
manifest.measurements.virtualPilotAcceptedCountByCase = acceptedCount;
manifest.measurements.virtualPilotFalseAcceptedCountByCase = ...
    falseAcceptedCount;
manifest.measurements.virtualPilotAcceptanceRateByCase = acceptanceRate;
manifest.measurements.virtualPilotFalseAcceptanceRateByCase = ...
    falseAcceptanceRate;
manifest.measurements.stage55SymbolErrorCountByCase = symbolErrorCount;
manifest.measurements.minimumAcceptanceRate = ...
    options.MinimumAcceptanceRate;
manifest.measurements.maximumFalseAcceptanceRate = ...
    options.MaximumFalseAcceptanceRate;
manifest.measurements.innovationGain = manifest.parameters.innovationGain;
manifest.measurements.innovationLimitHz = finalInnovationLimitHz;
manifest.measurements.maximumDataGapSec = maximumDataGapSec;
manifest.measurements.rateBudgetHz = rateBudgetHz;
manifest.measurements.measurementBudgetHz = measurementBudgetHz;
manifest.measurements.gridStepHz = gridStepHz;
manifest.measurements.usableSearchHalfWidthHz = usableSearchHalfWidthHz;
manifest.measurements.oneSymbolCausalDelayVerifiedByDesign = true;
manifest.validationPassed = validationPassed;
manifest.selectedFromPerformanceResults = false;
manifestFile = fullfile(root,'config','sf12ReceiverParameterManifest.json');
fid = fopen(manifestFile,'w');
assert(fid >= 0,'Cannot write receiver manifest.');
fileCleanup = onCleanup(@()fclose(fid));
fprintf(fid,'%s',jsonencode(manifest,'PrettyPrint',true));
resultFolder = fullfile(root,'results','calibration');
if ~isfolder(resultFolder), mkdir(resultFolder); end
save(fullfile(resultFolder,'sf12_mechanism_calibration.mat'), ...
    'manifest','offsetBins','errors','boundaryHits','acceptanceRate', ...
    'falseAcceptanceRate','symbolErrorCount');
end
