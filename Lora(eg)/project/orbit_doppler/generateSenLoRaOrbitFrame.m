function [rxSymbols, txSymbols, truth] = generateSenLoRaOrbitFrame( ...
        symbolBins, config, options)
%GENERATESENLORAORBITFRAME Generate a continuous dynamic-Doppler LoRa frame.
%
% The output matrices are Nsymbol-by-2^SF, matching the current SenLoRa
% receiver code.  The receiver never needs TRUTH; it is returned only for
% BER and trajectory diagnostics.

arguments
    symbolBins (:,1) double {mustBeInteger, mustBeNonnegative}
    config (1,1) struct
    options.StartTimeSec (1,1) double = NaN
    options.SampleSnrDb (1,1) double = -15
    options.Model (1,1) string = "paper_piecewise_linear"
    options.NoiseSeed (1,1) double = 20260804
end

numSymbols = numel(symbolBins);
sf = config.sf;
numSamples = 2^sf;
if any(symbolBins >= numSamples)
    error("SenLoRa:InvalidFrameSymbol", ...
        "Every frame symbol must be in [0, 2^SF-1].");
end
if ~ismember(options.Model, config.allowedDopplerModels)
    error("SenLoRa:InvalidDopplerModel", ...
        "Unsupported Doppler model.");
end
if isnan(options.StartTimeSec)
    options.StartTimeSec = config.scenarios(1).startTimeSec;
end

txSymbols = complex(zeros(numSymbols, numSamples));
rxSymbolsNoiseless = complex(zeros(numSymbols, numSamples));
sampleTimeSec = zeros(numSymbols, numSamples);
dopplerHz = zeros(numSymbols, numSamples);
dopplerRateHzPerSec = zeros(numSymbols, 1);
phaseRad = zeros(numSymbols, numSamples);
phaseStartRad = zeros(numSymbols, 1);
symbolStartTimeSec = zeros(numSymbols, 1);
trueCfoBins = zeros(numSymbols, 1);
trueDopplerHz = zeros(numSymbols, 1);
effectiveDopplerHz = zeros(numSymbols, 1);
previousLastFrequencyHz = 0;
previousLastPhaseRad = 0;
hasPreviousSymbol = false;

for symbolIdx = 1:numSymbols
    symbolStart = options.StartTimeSec + ...
        (symbolIdx-1)*config.symbolDurationSec;
    trace = senloraDopplerPiecewiseLinear( ...
        symbolBins(symbolIdx), sf, symbolStart, config.orbit, ...
        BandwidthHz=config.bandwidthHz);
    if options.Model == "paper_piecewise_linear"
        selectedFrequencyHz = trace.linearDopplerHz;
        localPhaseRad = trace.linearPhaseRad;
    else
        selectedFrequencyHz = trace.exactDopplerHz;
        localPhaseRad = trace.exactPhaseRad;
    end

    if hasPreviousSymbol
        boundaryIncrementRad = pi/config.sampleRateHz*( ...
            previousLastFrequencyHz + selectedFrequencyHz(1));
        firstPhaseRad = previousLastPhaseRad + boundaryIncrementRad;
        continuousPhaseRad = localPhaseRad + firstPhaseRad;
    else
        continuousPhaseRad = localPhaseRad;
        firstPhaseRad = continuousPhaseRad(1);
        hasPreviousSymbol = true;
    end

    waveform = senloraModulateLoRaSymbol(symbolBins(symbolIdx), sf);
    txSymbols(symbolIdx, :) = waveform;
    rxSymbolsNoiseless(symbolIdx, :) = waveform .* exp(1i*continuousPhaseRad.');
    sampleTimeSec(symbolIdx, :) = trace.sampleTimeSec.';
    dopplerHz(symbolIdx, :) = selectedFrequencyHz.';
    phaseRad(symbolIdx, :) = continuousPhaseRad.';
    phaseStartRad(symbolIdx) = firstPhaseRad;
    symbolStartTimeSec(symbolIdx) = symbolStart;
    centerIndex = floor(numSamples/2)+1;
    centerTime = trace.sampleTimeSec(centerIndex);
    centerTrajectory = senloraOrbitDopplerTrajectory(centerTime, config.orbit);
    trueDopplerHz(symbolIdx) = centerTrajectory.dopplerShiftHz;
    trueCfoBins(symbolIdx) = trueDopplerHz(symbolIdx)/config.fftBinSpacingHz;
    effectiveDopplerHz(symbolIdx) = selectedFrequencyHz(centerIndex);
    dopplerRateHzPerSec(symbolIdx) = centerTrajectory.dopplerRateHzPerSec;

    previousLastFrequencyHz = selectedFrequencyHz(end);
    previousLastPhaseRad = continuousPhaseRad(end);
end

sampleSnrLinear = 10^(options.SampleSnrDb/10);
noiseVariance = 10^(-options.SampleSnrDb/10);
noiseStream = RandStream("mt19937ar", "Seed", options.NoiseSeed);
noiseSigma = sqrt(noiseVariance/2);
noise = noiseSigma*(randn(noiseStream, size(rxSymbolsNoiseless)) + ...
    1i*randn(noiseStream, size(rxSymbolsNoiseless)));
rxSymbols = rxSymbolsNoiseless + noise;

[~, visible] = senloraVisibilityWindow(config.orbit, sampleTimeSec(:));
visible = reshape(visible, size(sampleTimeSec));
truth = struct( ...
    "symbolBins", symbolBins, ...
    "sampleTimeSec", sampleTimeSec, ...
    "symbolStartTimeSec", symbolStartTimeSec, ...
    "trueDopplerHz", trueDopplerHz, ...
    "trueCfoBins", trueCfoBins, ...
    "effectiveDopplerHz", effectiveDopplerHz, ...
    "trueDopplerRateHzPerSec", dopplerRateHzPerSec, ...
    "dopplerHz", dopplerHz, ...
    "phaseRad", phaseRad, ...
    "phaseStartRad", phaseStartRad, ...
    "visibleSampleMask", visible, ...
    "sampleSnrDb", options.SampleSnrDb, ...
    "sampleSnrLinear", sampleSnrLinear, ...
    "noiseVariance", noiseVariance, ...
    "model", options.Model, ...
    "startTimeSec", options.StartTimeSec);
end
