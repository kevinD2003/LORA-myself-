function experiment = fuxianComparisonConfig(options)
%FUXIANCOMPARISONCONFIG Freeze Stage55 and paper-transfer parameters.

arguments
    options.MidambleSpacingMode (1,1) string ...
        {mustBeMember(options.MidambleSpacingMode, ...
        ["paper_anchor", "full_pass_rate_matched", ...
        "visible_rate_matched"])} = "paper_anchor"
    options.IncludeTerminalMidamble (1,1) logical = false
end

comparisonRoot = fileparts(mfilename('fullpath'));
sourceRoot = fuxianSourceRoot(comparisonRoot);
config = satelliteFig3Config();
referenceSf = 12;
referenceBandwidthHz = 125e3;
referenceSpacing = 3;
spacingScale = (config.bandwidthHz/referenceBandwidthHz)^2* ...
    2^(2*(referenceSf-config.sf));
paperAnchorSpacing = round(referenceSpacing*spacingScale);
referenceDopplerRateHzPerSec = 279.089833;
schedule = satelliteFig3ContinuousPassSchedule(config);
trajectory = satelliteFig3Trajectory( ...
    schedule.frameCenterTimeSec,config);
fullPassRateHzPerSec = max(abs(trajectory.dopplerRateHzPerSec));
visibleRateHzPerSec = max(abs(trajectory.dopplerRateHzPerSec( ...
    schedule.fullyVisible)));
fullPassRateMatchedSpacing = round(paperAnchorSpacing* ...
    referenceDopplerRateHzPerSec/fullPassRateHzPerSec);
visibleRateMatchedSpacing = round(paperAnchorSpacing* ...
    referenceDopplerRateHzPerSec/visibleRateHzPerSec);
switch options.MidambleSpacingMode
    case "paper_anchor"
        midambleSpacing = paperAnchorSpacing;
    case "full_pass_rate_matched"
        midambleSpacing = fullPassRateMatchedSpacing;
    otherwise
        midambleSpacing = visibleRateMatchedSpacing;
end
trackingMidambleCount = floor( ...
    (config.payloadSymbolCount-1)/midambleSpacing);
toaMidambleCount = ceil(config.payloadSymbolCount/midambleSpacing);
terminalMidambleCount = toaMidambleCount-trackingMidambleCount;
transmittedMidambleCount = trackingMidambleCount + ...
    double(options.IncludeTerminalMidamble)*terminalMidambleCount;

physicalConfig = config;
physicalConfig.frameSymbolCount = config.bootstrapPilotCount + ...
    config.payloadSymbolCount + transmittedMidambleCount;

experiment.sourceRoot = sourceRoot;
experiment.config = config;
experiment.physicalConfig = physicalConfig;
experiment.snrGridDb = [-21;-20];
experiment.passCount = 3;
experiment.framesPerVisibleSegment = Inf;
experiment.payloadSeedBase = 2026551800;
experiment.noiseSeedBase = 2026551900;
experiment.windowDurationSec = 10;
experiment.referenceSf = referenceSf;
experiment.referenceBandwidthHz = referenceBandwidthHz;
experiment.referenceSpacing = referenceSpacing;
experiment.spacingScale = spacingScale;
experiment.midambleSpacingMode = options.MidambleSpacingMode;
experiment.paperAnchorSpacing = paperAnchorSpacing;
experiment.fullPassRateMatchedSpacing = fullPassRateMatchedSpacing;
experiment.visibleRateMatchedSpacing = visibleRateMatchedSpacing;
experiment.spacingSensitivity = unique([paperAnchorSpacing, ...
    fullPassRateMatchedSpacing,visibleRateMatchedSpacing]);
experiment.referenceDopplerRateHzPerSec = ...
    referenceDopplerRateHzPerSec;
experiment.fullPassRateHzPerSec = fullPassRateHzPerSec;
experiment.visibleRateHzPerSec = visibleRateHzPerSec;
experiment.midambleSpacing = midambleSpacing;
experiment.trackingMidambleCount = trackingMidambleCount;
experiment.toaMidambleCount = toaMidambleCount;
experiment.terminalMidambleCount = terminalMidambleCount;
experiment.includeTerminalMidamble = options.IncludeTerminalMidamble;
experiment.transmittedMidambleCount = transmittedMidambleCount;
% 兼容旧调用；该字段表示实际发送的Midamble数量。
experiment.midambleCount = transmittedMidambleCount;
experiment.midambleWaveformBin = 0;
experiment.methodNames = { ...
    'Huang-PREC-CP'; ...
    'Stage55-VP-quality'; ...
    'Paper-Midamble-Point'};
experiment.methodLabels = { ...
    'PREC (Huang)'; ...
    'SenLoRa'; ...
    'Paper Midamble-Point'};
experiment.fittedOrTuned = false;
end
