function validation = validate_ideal_ser(config,stageConfig,theoryCurve,summary,audit)
%VALIDATE_IDEAL_SER Acceptance checks for the independent ideal SER run.

checks = struct();
checks.sfMatches = stageConfig.physicalSf==config.sf;
checks.bandwidthMatches = stageConfig.bandwidthHz==config.bandwidthHz;
checks.sampleRateMatches = stageConfig.sampleRateHz==config.sampleRateHz;
checks.carrierMatches = stageConfig.carrierFrequencyHz==config.carrierFrequencyHz;
checks.payloadSymbolCountMatches = stageConfig.payloadSymbolCount==112;
checks.informationBitCountMatches = stageConfig.informationBitCount==768;
checks.physicalSymbolCountMatches = audit.physicalSymbolCount==157;
checks.noPerformanceInputs = isempty(config.performanceDataInputs) && ...
    ~config.fittedToFrozenData && ~config.existingPerformanceDataLoaded;
checks.theoryFinite = all(isfinite(theoryCurve.ser));
checks.theoryInRange = all(theoryCurve.ser>0 & theoryCurve.ser<1);
checks.theoryMonotone = all(diff(theoryCurve.ser)<0);
checks.noiselessDetection = all([audit.caseAudit.noiselessSymbolErrors]==0);
checks.perfectWaveformRecovery = all( ...
    [audit.caseAudit.maximumCompensatedWaveformError] ...
    <=config.noiselessTolerance);
noiseRelativeError = abs(summary.noisePowerMeasured./ ...
    summary.noisePowerExpected-1);
checks.noisePowerMatches = all(noiseRelativeError<= ...
    config.noisePowerRelativeTolerance);
checks.theoryInsideMonteCarloIntervals = ...
    all(summary.theoryInsideConfidenceInterval);
checks.fullFrameTimeline = audit.fullFrameTimelineUsed && ...
    audit.continuousDopplerPhaseUsed;
checks.channelAndCompensation = audit.complexAwgnUsed && ...
    audit.perfectSamplewiseCompensationUsed;

passed = all(structfun(@(value)logical(value),checks));
if passed,status = 'PASS';else,status = 'FAIL';end
validation = struct('status',status,'checks',checks, ...
    'maximumNoisePowerRelativeError',max(noiseRelativeError), ...
    'confidenceZ',config.confidenceZ, ...
    'fittedToFrozenData',false,'existingPerformanceDataLoaded',false);
end
