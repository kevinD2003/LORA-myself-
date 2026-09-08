function trace = buildTrackingTrace(cfg, caseName)
%BUILDTRACKINGTRACE Noise-free Point and Midamble-Point diagnostic trace.

arguments
    cfg (1,1) struct
    caseName (1,1) string
end

caseName = string(caseName);
if caseName == "case1"
    orbitStartS = cfg.orbit.case1StartTimeS;
elseif caseName == "case2"
    orbitStartS = cfg.orbit.case2StartTimeS;
else
    error('buildTrackingTrace:UnknownCase', ...
        'Unknown case: %s', caseName);
end
layout = buildFrameLayout(cfg);
initialTemplate = integratedDopplerTemplate( ...
    orbitStartS, layout.initialDownchirpStartS, cfg);
currentEstimateHz = estimateFftFrequency( ...
    initialTemplate, cfg.radio.sampleRateHz);
initialEstimateHz = currentEstimateHz;

midambleEstimateHz = nan(1, layout.payloadSymbols);
updateTimeS = nan(1, layout.numberOfMidambles + 1);
updateEstimateHz = nan(1, layout.numberOfMidambles + 1);
updateTimeS(1) = layout.payloadStartS;
updateEstimateHz(1) = currentEstimateHz;
updateCounter = 1;
dataCounter = 0;
sampleTimeS = (0:cfg.radio.samplesPerSymbol-1).'/ ...
    cfg.radio.sampleRateHz;
for slotIndex = 1:numel(layout.slotKind)
    template = integratedDopplerTemplate( ...
        orbitStartS, layout.slotStartS(slotIndex), cfg);
    if layout.slotKind(slotIndex) == "data"
        dataCounter = dataCounter + 1;
        midambleEstimateHz(dataCounter) = currentEstimateHz;
    else
        compensated = template.*exp(-1j*2*pi* ...
            sampleTimeS*currentEstimateHz);
        residualHz = estimateFftFrequency( ...
            compensated, cfg.radio.sampleRateHz);
        currentEstimateHz = updateMidamblePointEstimate( ...
            currentEstimateHz, residualHz);
        updateCounter = updateCounter + 1;
        updateTimeS(updateCounter) = layout.slotStartS(slotIndex);
        updateEstimateHz(updateCounter) = currentEstimateHz;
    end
end

dataTimeS = layout.midambleDataStartS;
trueDopplerHz = circularOrbitDoppler(orbitStartS + ...
    dataTimeS + 0.5*cfg.radio.symbolDurationS, cfg);
trace.caseName = caseName;
trace.spreadingFactor = cfg.radio.spreadingFactor;
trace.dataTimeS = dataTimeS;
trace.trueDopplerHz = trueDopplerHz;
trace.pointEstimateHz = repmat(initialEstimateHz, size(dataTimeS));
trace.midamblePointEstimateHz = midambleEstimateHz;
trace.updateTimeS = updateTimeS(1:updateCounter);
trace.updateEstimateHz = updateEstimateHz(1:updateCounter);
end
