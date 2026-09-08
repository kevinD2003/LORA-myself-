function paired = simulate_lora_dynamic_doppler_paired_point( ...
        orbitScenario, sf, snrDb, config)
%SIMULATE_LORA_DYNAMIC_DOPPLER_PAIRED_POINT 共同批次复核 paper/exact。
%   两模型在每一批使用同一符号与 AWGN；循环直到双方均满足停止条件。

orbitScenario = string(orbitScenario);
names = string({config.orbitScenarios.name});
scenarioIndex = find(names == orbitScenario, 1);
if isempty(scenarioIndex)
    error("lora:InvalidOrbitScenario", "Unknown orbit scenario.");
end
startTimeSec = config.orbitScenarios(scenarioIndex).startTimeSec;
orbit = config.geometry.configA;
m = 2^sf;
batchSymbols = min(config.maxSymbolsPerBatch, ...
    max(1, floor(config.maxComplexSamplesPerBatch/m)));
snrIndex = round(10*(snrDb + 100));
seedSymbols = config.baseSeedSymbols + 700000 + 10000*scenarioIndex + ...
    100*sf + snrIndex;
seedNoise = config.baseSeedNoise + 700000 + 10000*scenarioIndex + ...
    100*sf + snrIndex;
symbolStream = RandStream("mt19937ar", "Seed", seedSymbols);
noiseStream = RandStream("mt19937ar", "Seed", seedNoise);
paperErrors = 0; exactErrors = 0; paperSymbolErrors = 0; exactSymbolErrors = 0;
totalBits = 0; totalSymbols = 0; maxDopplerErrorHz = 0; phaseSquaredError = 0;
phaseSamples = 0; noiselessPeakEqual = true; energyDifference = 0;
[traceCacheEnabled, txCache, paperPhaseCache, exactPhaseCache, ...
    paperFdCache, exactFdCache] = make_fixed_start_trace_cache();

while totalBits < config.maxBitsPerPoint && ...
        ~(paperErrors >= config.targetBitErrors && exactErrors >= config.targetBitErrors)
    remainingSymbols = floor((config.maxBitsPerPoint-totalBits)/sf);
    if remainingSymbols < 1, break, end
    count = min(batchSymbols, remainingSymbols);
    transmitted = randi(symbolStream, [0,m-1], 1, count, "uint32");
    if traceCacheEnabled
        cacheColumns = double(transmitted) + 1;
        tx = txCache(:, cacheColumns);
        paperPhase = paperPhaseCache(:, cacheColumns);
        exactPhase = exactPhaseCache(:, cacheColumns);
        paperFd = paperFdCache(:, cacheColumns);
        exactFd = exactFdCache(:, cacheColumns);
    else
        tx = lora_css_modulate(transmitted, sf);
        paperPhase = zeros(m,count); exactPhase = zeros(m,count);
        paperFd = zeros(m,count); exactFd = zeros(m,count);
        for column = 1:count
            trace = lora_doppler_piecewise_linear(transmitted(column), sf, ...
                startTimeSec, orbit, BandwidthHz=config.bandwidthHz);
            paperPhase(:,column) = trace.linearPhaseRad;
            exactPhase(:,column) = trace.exactPhaseRad;
            paperFd(:,column) = trace.linearDopplerHz;
            exactFd(:,column) = trace.exactDopplerHz;
        end
    end
    if isinf(snrDb)
        noise = complex(zeros(m,count));
    else
        noiseVariance = 10^(-snrDb/10);
        noise = sqrt(noiseVariance/2)*(randn(noiseStream,m,count) + ...
            1i*randn(noiseStream,m,count));
    end
    noiselessPaper = tx.*exp(1i*paperPhase);
    noiselessExact = tx.*exp(1i*exactPhase);
    detectedPaper = lora_css_demodulate(noiselessPaper+noise, sf);
    detectedExact = lora_css_demodulate(noiselessExact+noise, sf);
    [thisPaperErrors,thisPaperSymbols] = count_errors(transmitted,detectedPaper,sf);
    [thisExactErrors,thisExactSymbols] = count_errors(transmitted,detectedExact,sf);
    paperErrors = paperErrors + thisPaperErrors; exactErrors = exactErrors + thisExactErrors;
    paperSymbolErrors = paperSymbolErrors + thisPaperSymbols;
    exactSymbolErrors = exactSymbolErrors + thisExactSymbols;
    totalBits = totalBits + count*sf; totalSymbols = totalSymbols + count;
    maxDopplerErrorHz = max(maxDopplerErrorHz, max(abs(paperFd-exactFd),[],"all"));
    phaseSquaredError = phaseSquaredError + sum((paperPhase-exactPhase).^2,"all");
    phaseSamples = phaseSamples + numel(paperPhase);
    if totalSymbols == count
        peakPaper = lora_css_demodulate(noiselessPaper,sf);
        peakExact = lora_css_demodulate(noiselessExact,sf);
        noiselessPeakEqual = all(peakPaper == peakExact);
        energyDifference = norm(abs(fft(noiselessPaper)).^2 - ...
            abs(fft(noiselessExact)).^2,"fro")/max(1,norm(abs(fft(noiselessExact)).^2,"fro"));
    end
end
paperBer = paperErrors/totalBits; exactBer = exactErrors/totalBits;
combinedSe = sqrt(paperBer*(1-paperBer)/totalBits + exactBer*(1-exactBer)/totalBits);
relativeTerm = 0; if max(paperBer,exactBer)>1e-3, relativeTerm=0.1*max(paperBer,exactBer); end
threshold = max(3*combinedSe,relativeTerm);
paper = make_result("paper_piecewise_linear",paperErrors,paperSymbolErrors);
exact = make_result("exact_orbit_sampled",exactErrors,exactSymbolErrors);
paired = struct("paper",paper,"exact",exact,"max_doppler_error_hz",maxDopplerErrorHz, ...
    "rms_phase_error_rad",sqrt(phaseSquaredError/phaseSamples), ...
    "noiseless_fft_peak_equal",noiselessPeakEqual,"fft_energy_relative_error",energyDifference, ...
    "difference_ber",abs(paperBer-exactBer),"consistency_threshold",threshold, ...
    "statistically_consistent",abs(paperBer-exactBer)<=threshold, ...
    "trace_cache_enabled",traceCacheEnabled, ...
    "trace_cache_entries",double(traceCacheEnabled)*m);

    function result = make_result(model, bitErrors, symbolErrors)
        result = struct("doppler_model",model,"ber",bitErrors/totalBits, ...
            "ser",symbolErrors/totalSymbols,"bit_errors",bitErrors, ...
            "symbol_errors",symbolErrors,"total_bits",totalBits, ...
            "total_symbols",totalSymbols,"seed_symbols",seedSymbols, ...
            "seed_noise",seedNoise);
    end

    function [enabled, cachedTx, cachedPaperPhase, cachedExactPhase, ...
            cachedPaperFd, cachedExactFd] = make_fixed_start_trace_cache()
        enabled = string(config.timeMode) == ...
            "fixed_orbit_start_independent_symbols" && ...
            m*m <= config.maxComplexSamplesPerBatch;
        cachedTx = zeros(m, 0);
        cachedPaperPhase = zeros(m, 0);
        cachedExactPhase = zeros(m, 0);
        cachedPaperFd = zeros(m, 0);
        cachedExactFd = zeros(m, 0);
        if ~enabled
            return
        end
        symbolValues = uint32(0:m-1);
        cachedTx = lora_css_modulate(symbolValues, sf);
        cachedPaperPhase = zeros(m, m);
        cachedExactPhase = zeros(m, m);
        cachedPaperFd = zeros(m, m);
        cachedExactFd = zeros(m, m);
        for symbolIndex = 1:m
            trace = lora_doppler_piecewise_linear( ...
                symbolValues(symbolIndex), sf, startTimeSec, orbit, ...
                BandwidthHz=config.bandwidthHz);
            cachedPaperPhase(:, symbolIndex) = trace.linearPhaseRad;
            cachedExactPhase(:, symbolIndex) = trace.exactPhaseRad;
            cachedPaperFd(:, symbolIndex) = trace.linearDopplerHz;
            cachedExactFd(:, symbolIndex) = trace.exactDopplerHz;
        end
    end
end

function [bitErrors,symbolErrors] = count_errors(transmitted,detected,sf)
xorValues = bitxor(transmitted(:),detected(:)); bitErrors = 0;
for bitIndex=1:sf, bitErrors = bitErrors + nnz(bitget(xorValues,bitIndex)); end
symbolErrors = nnz(transmitted(:) ~= detected(:));
end
