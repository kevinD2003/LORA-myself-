function result = simulate_lora_css_awgn_point(sf, snrDb, config)
%SIMULATE_LORA_CSS_AWGN_POINT Exact FFT-domain Monte Carlo for one point.
%   This function samples the sufficient statistics produced by the
%   implemented unit-power CSS waveform, complex AWGN, dechirping, and
%   unnormalized M-point FFT detector.

m = 2^sf;
snrLinear = 10^(snrDb/10);
correctBinMean = sqrt(m * snrLinear);
numberWrongBins = m - 1;

snrIndex = round((snrDb - config.snrDb(1))/config.snrStepDb);
pointSeed = config.randomSeed + 1000*sf + snrIndex;
rng(pointSeed, 'twister');

bitErrors = 0;
symbolErrors = 0;
totalBits = 0;
totalSymbols = 0;
completedBatches = 0;
timer = tic;

while bitErrors < config.targetBitErrors && ...
        totalBits < config.maxBitsPerPoint
    remainingSymbols = floor( ...
        (config.maxBitsPerPoint - totalBits) / sf);
    if remainingSymbols < 1
        break;
    end
    numberSymbols = min(config.batchSymbols, remainingSymbols);

    transmitted = randi([0, m-1], numberSymbols, 1, 'uint32');

    correctNoise = (randn(numberSymbols, 1) + ...
        1i*randn(numberSymbols, 1)) / sqrt(2);
    correctPower = abs(correctBinMean + correctNoise).^2;

    % If P_k~Exp(1), max(P_1,...,P_K) has inverse CDF
    % -log(1-U^(1/K)). expm1 preserves precision for large K.
    logUniform = log(rand(numberSymbols, 1));
    oneMinusRoot = -expm1(logUniform / numberWrongBins);
    maxWrongPower = -log(oneMinusRoot);

    errorMask = maxWrongPower > correctPower;
    errorsThisBatch = nnz(errorMask);
    symbolErrors = symbolErrors + errorsThisBatch;

    if errorsThisBatch > 0
        transmittedErrors = transmitted(errorMask);
        wrongBase = randi([0, m-2], errorsThisBatch, 1, 'uint32');
        detectedErrors = wrongBase + ...
            uint32(wrongBase >= transmittedErrors);
        xorValues = bitxor(transmittedErrors, detectedErrors);
        for bitIndex = 1:sf
            bitErrors = bitErrors + ...
                double(sum(bitget(xorValues, bitIndex)));
        end
    end

    totalSymbols = totalSymbols + numberSymbols;
    totalBits = totalBits + numberSymbols*sf;
    completedBatches = completedBatches + 1;
end

if bitErrors == 0
    ber = NaN;
    plotBer = 1/totalBits;
    isUpperBound = true;
else
    ber = bitErrors/totalBits;
    plotBer = ber;
    isUpperBound = false;
end

if symbolErrors == 0
    ser = NaN;
else
    ser = symbolErrors/totalSymbols;
end

if bitErrors >= config.targetBitErrors
    stopReason = "target_bit_errors";
else
    stopReason = "maximum_bits";
end

result = struct( ...
    'sf', sf, ...
    'snr_db', snrDb, ...
    'bit_errors', bitErrors, ...
    'total_bits', totalBits, ...
    'ber', ber, ...
    'ber_upper_bound', 1/totalBits, ...
    'plot_ber', plotBer, ...
    'is_upper_bound', isUpperBound, ...
    'symbol_errors', symbolErrors, ...
    'total_symbols', totalSymbols, ...
    'ser', ser, ...
    'monte_carlo_batches', completedBatches, ...
    'symbols_per_batch', config.batchSymbols, ...
    'seed', pointSeed, ...
    'stop_reason', stopReason, ...
    'elapsed_seconds', toc(timer), ...
    'mode', config.monteCarloMode);
end
