function manifest = runSf12MechanismCalibration(options)
%RUNSF12MECHANISMCALIBRATION Measure SF12 CFO scale and freeze manifest.

arguments
    options.PacketCount (1,1) double {mustBeInteger,mustBePositive} = 100
    options.SnrDb (1,1) double = -21
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
validationPackets = min(20,options.PacketCount);
acceptedCount = 0;
falseAcceptedCount = 0;
for packet = 1:validationPackets
    paired = sf12PairedFrameSimulation(cfg,"case1",options.SnrDb, ...
        packet,"calibration",1);
    acceptedCount = acceptedCount+paired.stage55AcceptedVirtualPilots;
    falseAcceptedCount = falseAcceptedCount+ ...
        paired.stage55FalseAcceptedVirtualPilots;
end
manifest.measurements.virtualPilotAcceptedCount = acceptedCount;
manifest.measurements.virtualPilotFalseAcceptedCount = falseAcceptedCount;
manifest.measurements.virtualPilotFalseAcceptanceRate = ...
    falseAcceptedCount/max(acceptedCount,1);
manifest.measurements.innovationGain = manifest.parameters.innovationGain;
manifest.measurements.innovationLimitHz = ...
    manifest.parameters.innovationLimitHz;
manifest.measurements.oneSymbolCausalDelayVerifiedByDesign = true;
manifest.parameters.singleSymbolCfoStdHz = stdHz;
manifest.parameters.innovationLimitHz = max( ...
    0.5*cfg.radio.fftBinHz,2*q95);
manifest.selectedFromPerformanceResults = false;
manifestFile = fullfile(root,'config','sf12ReceiverParameterManifest.json');
fid = fopen(manifestFile,'w');
assert(fid >= 0,'Cannot write receiver manifest.');
fileCleanup = onCleanup(@()fclose(fid));
fprintf(fid,'%s',jsonencode(manifest,'PrettyPrint',true));
resultFolder = fullfile(root,'results','calibration');
if ~isfolder(resultFolder), mkdir(resultFolder); end
save(fullfile(resultFolder,'sf12_mechanism_calibration.mat'), ...
    'manifest','offsetBins','errors','boundaryHits');
end
