function point = simulateSenLoRaBerPoint( ...
        config, scenarioIndex, snrDb, options)
%SIMULATESENLORABERPOINT Common-random-number BER point.
%
% All receiver strategies consume exactly the same transmitted frame, orbit
% start, and AWGN realization.  Receiver truth is used only for the
% truth-filtered evaluation curve and for diagnostics.

arguments
    config (1,1) struct
    scenarioIndex (1,1) double {mustBeInteger,mustBePositive}
    snrDb (1,1) double
    options.TargetBitErrors (1,1) double = 300
    options.MinBits (1,1) double {mustBeNonnegative} = 0
    options.MaxBits (1,1) double = 1e6
    options.MaxFrames (1,1) double = Inf
    options.SymbolSeed (1,1) double = 20260803
    options.NoiseSeed (1,1) double = 20260804
    options.Methods (1,:) string = ["raw","static_prec","blind_hard", ...
        "senlora","truth_upper","ideal"]
end

supportedMethods = ["raw","static_prec","blind_hard","senlora", ...
    "truth_upper","ideal"];
methodNames = options.Methods;
if isempty(methodNames) || numel(unique(methodNames)) ~= numel(methodNames) || ...
        any(~ismember(methodNames,supportedMethods))
    error("SenLoRa:InvalidBerMethods", ...
        "Methods must be unique names from the supported receiver set.");
end
if options.MinBits > options.MaxBits
    error("SenLoRa:InvalidBerBitLimits", ...
        "MinBits must not exceed MaxBits.");
end
methodCount = numel(methodNames);
bitErrors = zeros(methodCount,1);
symbolErrors = zeros(methodCount,1);
pilotCounts = zeros(methodCount,1);
frameBerSum = zeros(methodCount,1);
frameBerSquareSum = zeros(methodCount,1);
totalBits = 0;
totalSymbols = 0;
frameCount = 0;
scenario = config.scenarios(scenarioIndex);
bootstrapCount = config.bootstrapPilotCount;
payloadCount = config.payloadSymbolCount;
payloadMask = false(config.frameSymbolCount,1);
payloadMask((bootstrapCount+1):end) = true;
symbolStream = RandStream("mt19937ar","Seed", ...
    options.SymbolSeed + 100000*scenarioIndex + round(10*snrDb+1000));
frameLimit = options.MaxFrames;
dynamicFalseAcceptCount = 0;
dynamicResidualSum = 0;
dynamicResidualCount = 0;
dynamicMaxResidual = 0;
dynamicRateSumHzPerSec = 0;
dynamicRateCount = 0;
diagnosticTrace = struct([]);

while totalBits < options.MaxBits && ...
        (totalBits < options.MinBits || ...
        any(bitErrors < options.TargetBitErrors)) && ...
        frameCount < frameLimit
    payloadBins = senloraGenerateCodedPayloadBins(config,symbolStream);
    symbolBins = [zeros(bootstrapCount,1); double(payloadBins)];
    noiseSeed = options.NoiseSeed + 100000*scenarioIndex + ...
        frameCount + round(10*snrDb+1000);
    [rxSymbols,~,truth] = generateSenLoRaOrbitFrame( ...
        symbolBins,config,StartTimeSec=scenario.startTimeSec, ...
        SampleSnrDb=snrDb,NoiseSeed=noiseSeed);

    detected = zeros(config.frameSymbolCount,methodCount);
    dynamic = struct([]);
    for methodIdx = 1:methodCount
        switch methodNames(methodIdx)
            case "raw"
                detected(:,methodIdx) = senloraDecodeRaw(rxSymbols,config);
            case "static_prec"
                detected(:,methodIdx) = senloraStaticPrecDecode( ...
                    rxSymbols,config,zeros(bootstrapCount,1));
            case "blind_hard"
                blind = senloraBlindHardUpdateDecode( ...
                    rxSymbols,config,zeros(bootstrapCount,1));
                detected(:,methodIdx) = blind.detectedBins;
                pilotCounts(methodIdx) = pilotCounts(methodIdx) + ...
                    sum(blind.pilotUpdateFlag(bootstrapCount+1:end));
            case "senlora"
                dynamic = senloraDynamicConfidenceIteration( ...
                    rxSymbols,config,zeros(bootstrapCount,1));
                detected(:,methodIdx) = dynamic.detectedBins;
                pilotCounts(methodIdx) = pilotCounts(methodIdx) + ...
                    sum(dynamic.pilotUpdateFlag(bootstrapCount+1:end));
            case "truth_upper"
                truthUpper = senloraTruthFilteredDecode( ...
                    rxSymbols,symbolBins,config,zeros(bootstrapCount,1));
                detected(:,methodIdx) = truthUpper.detectedBins;
                pilotCounts(methodIdx) = pilotCounts(methodIdx) + ...
                    sum(truthUpper.pilotUpdateFlag(bootstrapCount+1:end));
            case "ideal"
                detected(:,methodIdx) = ...
                    senloraIdealPhaseDecode(rxSymbols,truth,config);
        end
    end

    if ~isempty(dynamic)
        dynamicPayloadAccepted = dynamic.pilotUpdateFlag(payloadMask);
        dynamicPayloadResidual = dynamic.measuredResidualBins(payloadMask);
        dynamicResidualMask = dynamicPayloadAccepted & ...
            isfinite(dynamicPayloadResidual);
        dynamicFalseAcceptCount = dynamicFalseAcceptCount + nnz( ...
            dynamicPayloadAccepted & ...
            (dynamic.detectedBins(payloadMask) ~= symbolBins(payloadMask)));
        dynamicResidualSum = dynamicResidualSum + ...
            sum(abs(dynamicPayloadResidual(dynamicResidualMask)));
        dynamicResidualCount = dynamicResidualCount + nnz(dynamicResidualMask);
        if any(dynamicResidualMask)
            dynamicMaxResidual = max(dynamicMaxResidual, ...
                max(abs(dynamicPayloadResidual(dynamicResidualMask))));
        end
        dynamicPayloadRate = dynamic.predictedRateHzPerSec(payloadMask);
        dynamicRateMask = isfinite(dynamicPayloadRate);
        dynamicRateSumHzPerSec = dynamicRateSumHzPerSec + ...
            sum(dynamicPayloadRate(dynamicRateMask));
        dynamicRateCount = dynamicRateCount + nnz(dynamicRateMask);
        if isempty(diagnosticTrace)
            diagnosticTrace = struct( ...
                "scenario",scenario.name, ...
                "snrDb",snrDb, ...
                "symbolBins",symbolBins, ...
                "detectedBins",dynamic.detectedBins, ...
                "confidence",dynamic.confidence, ...
                "confidenceMask",dynamic.finalMask, ...
                "pilotUpdateFlag",dynamic.pilotUpdateFlag, ...
                "residualBins",dynamic.measuredResidualBins, ...
                "residualPeakRatio",dynamic.residualPeakRatio, ...
                "predictedCfoBins",dynamic.predictedCfoBins, ...
                "predictedRateHzPerSec",dynamic.predictedRateBinsPerSec* ...
                    config.fftBinSpacingHz, ...
                "pilotCount",dynamic.pilotCount);
        end
    end

    for methodIdx = 1:methodCount
        frameTrue = symbolBins(payloadMask);
        frameDetected = detected(payloadMask,methodIdx);
        frameBitErrors = senloraCountBitErrors( ...
            frameTrue,frameDetected,config.sf);
        bitErrors(methodIdx) = bitErrors(methodIdx) + frameBitErrors;
        frameBer = frameBitErrors/(payloadCount*config.sf);
        frameBerSum(methodIdx) = frameBerSum(methodIdx) + frameBer;
        frameBerSquareSum(methodIdx) = frameBerSquareSum(methodIdx) + frameBer^2;
        symbolErrors(methodIdx) = symbolErrors(methodIdx) + ...
            nnz(frameTrue ~= frameDetected);
    end
    totalBits = totalBits + payloadCount*config.sf;
    totalSymbols = totalSymbols + payloadCount;
    frameCount = frameCount + 1;
end

ber = bitErrors/max(totalBits,1);
ser = symbolErrors/max(totalSymbols,1);
upper95 = 1-0.05^(1/max(totalBits,1));
frameBerMean = frameBerSum/max(frameCount,1);
if frameCount > 1
    frameBerVariance = max(0,(frameBerSquareSum- ...
        frameCount*frameBerMean.^2)/(frameCount-1));
    frameBerStandardError = sqrt(frameBerVariance/frameCount);
else
    frameBerStandardError = nan(methodCount,1);
end
frameBerLower95 = max(0,frameBerMean-1.96*frameBerStandardError);
frameBerUpper95 = min(1,frameBerMean+1.96*frameBerStandardError);
zeroMethodMask = bitErrors==0;
frameBerLower95(zeroMethodMask) = 0;
frameBerUpper95(zeroMethodMask) = upper95;
method = repmat(struct(),methodCount,1);
for methodIdx = 1:methodCount
    method(methodIdx).name = methodNames(methodIdx);
    method(methodIdx).bitErrors = bitErrors(methodIdx);
    method(methodIdx).symbolErrors = symbolErrors(methodIdx);
    method(methodIdx).totalBits = totalBits;
    method(methodIdx).totalSymbols = totalSymbols;
    method(methodIdx).ber = ber(methodIdx);
    method(methodIdx).ser = ser(methodIdx);
    method(methodIdx).berUpper95Zero = upper95;
    method(methodIdx).frameBerStandardError = ...
        frameBerStandardError(methodIdx);
    method(methodIdx).frameBerLower95 = frameBerLower95(methodIdx);
    method(methodIdx).frameBerUpper95 = frameBerUpper95(methodIdx);
    method(methodIdx).meanPayloadPilotCount = pilotCounts(methodIdx)/max(frameCount,1);
    method(methodIdx).falseAcceptCount = 0;
    method(methodIdx).meanAbsResidualBins = NaN;
    method(methodIdx).maxAbsResidualBins = NaN;
    method(methodIdx).meanPredictedRateHzPerSec = NaN;
end
dynamicIndex = find(methodNames=="senlora",1);
if ~isempty(dynamicIndex)
    method(dynamicIndex).falseAcceptCount = dynamicFalseAcceptCount;
    method(dynamicIndex).meanAbsResidualBins = ...
        dynamicResidualSum/max(dynamicResidualCount,1);
    method(dynamicIndex).maxAbsResidualBins = dynamicMaxResidual;
    method(dynamicIndex).meanPredictedRateHzPerSec = ...
        dynamicRateSumHzPerSec/max(dynamicRateCount,1);
end

point = struct( ...
    "scenario",scenario.name, ...
    "scenarioIndex",scenarioIndex, ...
    "snrDb",snrDb, ...
    "sf",config.sf, ...
    "dopplerModel",config.dopplerModel, ...
    "frameCount",frameCount, ...
    "methods",method, ...
    "seedSymbols",options.SymbolSeed + 100000*scenarioIndex + ...
        round(10*snrDb+1000), ...
    "seedNoiseBase",options.NoiseSeed + 100000*scenarioIndex + ...
        round(10*snrDb+1000), ...
    "maxBitsReached",totalBits >= options.MaxBits, ...
    "minBitsReached",totalBits >= options.MinBits, ...
    "targetErrorsReached",bitErrors >= options.TargetBitErrors, ...
    "diagnosticTrace",diagnosticTrace);
end
