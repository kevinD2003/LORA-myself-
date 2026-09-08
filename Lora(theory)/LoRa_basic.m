%% LoRa CSS basic waveform and AWGN BER reproduction
% Based on the original single-symbol example supplied by the user.
% MATLAB R2022a or newer is recommended.
%
% BER scope:
%   * Standard uncoded LoRa CSS, SF7-SF12
%   * Complex baseband AWGN only
%   * Perfect synchronization
%   * Noncoherent dechirp-FFT peak detection
%   * No Doppler, CFO, STO, fading, interference, FEC, or framing
%
% Figure convention:
%   * Smooth solid lines: exact BER of this AWGN detector
%   * Markers: unmodified adaptive Monte Carlo results

clear;
clc;
close all;

projectFolder = fileparts(mfilename('fullpath'));
if isempty(projectFolder)
    projectFolder = pwd;
end

%% Reproduction configuration
config.bandwidthHz = 125e3;
config.sampleRateHz = config.bandwidthHz;
config.spreadingFactors = 7:12;
config.snrStepDb = 0.25;
config.snrDb = -26:config.snrStepDb:-5.5;
config.randomSeed = 2022;

% Adaptive Monte Carlo: work is concentrated near BER = 1e-6.
config.batchSymbols = 100000;
config.targetBitErrors = 200;
config.maxBitsPerPoint = 3e8;
config.targetBerFloor = 1e-6;
config.minimumTailBitErrors = 50;

% Random-symbol sequence demonstration.
config.showRandomSequenceDemo = true;
config.demoSf = 9;
config.demoSymbolCount = 20;
config.demoSnrDb = -10;

rng(config.randomSeed, 'twister');

%% Random LoRa CSS symbol sequence
if config.showRandomSequenceDemo
    sf = config.demoSf;
    m = 2^sf;
    k = (0:m-1).';
    transmittedSymbols = randi([0, m-1], ...
        1, config.demoSymbolCount, 'uint32');

    % Every column is one random LoRa CSS symbol.
    txMatrix = css_modulate(transmittedSymbols, sf);
    noiseVariance = 10^(-config.demoSnrDb/10);
    noiseMatrix = sqrt(noiseVariance/2) .* ...
        (randn(size(txMatrix)) + 1i*randn(size(txMatrix)));
    rxMatrix = txMatrix + noiseMatrix;
    detectedSymbols = css_demodulate(rxMatrix, sf);
    rxSequence = rxMatrix(:);

    % Coherent/noncoherent metrics for the first symbol in the sequence.
    downChirp = exp(-1i*2*pi*k.^2/(2*m) + 1i*pi*k);
    fftOutput = fft(rxMatrix(:, 1) .* downChirp)/m;
    coherentMetric = real(fftOutput);
    noncoherentMetric = abs(fftOutput);

    figure('Color', 'white', ...
        'Name', 'LoRa random-symbol sequence', ...
        'NumberTitle', 'off');
    tiledlayout(2, 1);
    nexttile;
    plot(0:numel(rxSequence)-1, real(rxSequence), 'LineWidth', 0.8);
    xlim([0, numel(rxSequence)-1]);
    xlabel('Sample index, k');
    ylabel('Real\{r[k]\}');
    title(sprintf('Random LoRa CSS sequence: SF%d, %d symbols', ...
        sf, config.demoSymbolCount));
    grid on;

    nexttile;
    plot(0:numel(rxSequence)-1, imag(rxSequence), 'LineWidth', 0.8);
    xlim([0, numel(rxSequence)-1]);
    xlabel('Sample index, k');
    ylabel('Imag\{r[k]\}');
    grid on;

    figure('Color', 'white', ...
        'Name', 'Coherent and noncoherent FFT metrics', ...
        'NumberTitle', 'off');
    tiledlayout(3, 1);
    nexttile;
    stem(0:m-1, coherentMetric, ...
        'Marker', 'none', 'LineWidth', 1);
    xlim([0, m-1]);
    xlabel('FFT bin, q');
    ylabel('Re\{Y[q]\}/M');
    title('Coherent metric with known zero phase');
    grid on;

    nexttile;
    stem(0:m-1, noncoherentMetric, ...
        'Marker', 'none', 'LineWidth', 1);
    xlim([0, m-1]);
    xlabel('FFT bin, q');
    ylabel('|Y[q]|/M');
    title('Noncoherent LoRa CSS detection metric');
    grid on;

    nexttile;
    symbolIndex = 1:config.demoSymbolCount;
    stairs(symbolIndex, double(transmittedSymbols), ...
        'o-', 'LineWidth', 1, 'DisplayName', 'Transmitted');
    hold on;
    stairs(symbolIndex, double(detectedSymbols), ...
        'x--', 'LineWidth', 1, 'DisplayName', 'Detected');
    xlim([1, config.demoSymbolCount]);
    xlabel('Symbol index');
    ylabel('Symbol value');
    title(sprintf('Random-symbol detection: %d/%d correct', ...
        nnz(detectedSymbols == transmittedSymbols), ...
        config.demoSymbolCount));
    legend('Location', 'best');
    grid on;
end

%% Internal checks before BER simulation
fprintf('Running LoRa_basic internal checks...\n');
run_internal_checks();
fprintf('All internal checks passed.\n');

%% Exact theoretical BER of the same noncoherent detector
sfList = config.spreadingFactors;
snrList = config.snrDb;
theoryBer = zeros(numel(snrList), numel(sfList));
for sfIndex = 1:numel(sfList)
    theoryBer(:, sfIndex) = css_theoretical_ber( ...
        sfList(sfIndex), snrList);
end

%% Adaptive Monte Carlo BER simulation
maximumPoints = numel(sfList)*numel(snrList);
resultCells = cell(maximumPoints, 1);
resultIndex = 0;
simulationTimer = tic;

for sf = sfList
    fprintf('Simulating SF%d...\n', sf);
    for snrDb = snrList
        resultIndex = resultIndex + 1;
        pointResult = simulate_ber_point(sf, snrDb, config);
        resultCells{resultIndex} = pointResult;

        if ~isnan(pointResult.ber) && ...
                pointResult.ber <= config.targetBerFloor && ...
                pointResult.bit_errors >= config.minimumTailBitErrors
            fprintf(['  BER tail reached at %.2f dB: %.3g ' ...
                '(%d errors, %d bits).\n'], ...
                snrDb, pointResult.ber, ...
                pointResult.bit_errors, pointResult.total_bits);
            break;
        end
    end
end

elapsedSeconds = toc(simulationTimer);
results = struct2table(vertcat(resultCells{1:resultIndex}));
results.theoretical_ber = NaN(height(results), 1);
for sf = sfList
    rows = results.sf == sf;
    [~, snrIndices] = ismember(results.snr_db(rows), snrList);
    sfIndex = find(sfList == sf, 1);
    results.theoretical_ber(rows) = theoryBer(snrIndices, sfIndex);
end

%% Smooth theoretical lines and raw Monte Carlo markers
figureHandle = figure('Color', 'white', ...
    'Position', [100, 100, 1000, 650], ...
    'Name', 'LoRa CSS AWGN BER: SF7-SF12', ...
    'NumberTitle', 'off');
axesHandle = axes(figureHandle);
hold(axesHandle, 'on');

colors = lines(numel(sfList));
markers = {'o', 's', '^', 'd', 'v', '>'};
lineHandles = gobjects(numel(sfList), 1);
markerStride = max(1, round(1/config.snrStepDb));

for sfIndex = 1:numel(sfList)
    sf = sfList(sfIndex);
    validTheory = theoryBer(:, sfIndex) > 0 & ...
        isfinite(theoryBer(:, sfIndex));
    theorySnr = snrList(validTheory).';
    theoryValues = theoryBer(validTheory, sfIndex);

    denseSnr = linspace(theorySnr(1), theorySnr(end), 1600).';
    denseLogBer = interp1(theorySnr, log10(theoryValues), ...
        denseSnr, 'pchip');
    lineHandles(sfIndex) = semilogy(axesHandle, ...
        denseSnr, 10.^denseLogBer, ...
        'Color', colors(sfIndex, :), ...
        'LineWidth', 1.6, ...
        'DisplayName', sprintf('CSS, SF=%d', sf));

    rows = results.sf == sf & ~isnan(results.ber);
    sfSnr = results.snr_db(rows);
    sfBer = results.ber(rows);
    markerRows = unique([ ...
        1:markerStride:numel(sfSnr), numel(sfSnr)]);
    semilogy(axesHandle, ...
        sfSnr(markerRows), sfBer(markerRows), ...
        'LineStyle', 'none', ...
        'Marker', markers{sfIndex}, ...
        'MarkerSize', 5, ...
        'Color', colors(sfIndex, :), ...
        'HandleVisibility', 'off');
end

grid(axesHandle, 'on');
axesHandle.YScale = 'log';
axesHandle.FontSize = 11;
axesHandle.LineWidth = 1;
xlim(axesHandle, [snrList(1), snrList(end)]);
ylim(axesHandle, [1e-6, 1e-1]);
xticks(axesHandle, -26:2:-6);
xlabel(axesHandle, 'SNR (dB)');
ylabel(axesHandle, 'BER');
title(axesHandle, { ...
    'LoRa CSS BER under complex AWGN', ...
    'Solid lines: exact theory; markers: adaptive Monte Carlo'});
legend(axesHandle, lineHandles, 'Location', 'southwest');
drawnow;
figure(figureHandle);

%% Save compact outputs
csvPath = fullfile(projectFolder, 'LoRa_basic_ber_results.csv');
pngPath = fullfile(projectFolder, 'LoRa_basic_ber.png');
pdfPath = fullfile(projectFolder, 'LoRa_basic_ber.pdf');
metadataPath = fullfile(projectFolder, 'LoRa_basic_metadata.json');
reportPath = fullfile(projectFolder, 'LoRa_basic_report.md');

writetable(results, csvPath);
exportgraphics(figureHandle, pngPath, 'Resolution', 300);
exportgraphics(figureHandle, pdfPath, 'ContentType', 'vector');

metadata = struct();
metadata.generatedAt = char(datetime( ...
    'now', 'Format', 'yyyy-MM-dd''T''HH:mm:ss'));
metadata.matlabVersion = version;
metadata.configuration = config;
metadata.simulationPoints = height(results);
metadata.totalSymbols = sum(results.total_symbols);
metadata.totalBits = sum(results.total_bits);
metadata.elapsedSeconds = elapsedSeconds;
metadata.lineMeaning = "exact noncoherent CSS theory";
metadata.markerMeaning = "raw adaptive Monte Carlo results";
fileId = fopen(metadataPath, 'w');
cleanup = onCleanup(@() fclose(fileId));
fwrite(fileId, jsonencode(metadata, 'PrettyPrint', true), 'char');
clear cleanup;

fileId = fopen(reportPath, 'w');
cleanup = onCleanup(@() fclose(fileId));
fprintf(fileId, '# LoRa_basic AWGN BER report\n\n');
fprintf(fileId, ['This self-contained script implements random LoRa CSS ' ...
    'symbol sequences and extends them to SF7-SF12 BER simulation.\n\n']);
fprintf(fileId, ['The model is uncoded LoRa CSS with perfect ' ...
    'synchronization and complex AWGN only. BER detection is ' ...
    'noncoherent dechirp-FFT peak selection.\n\n']);
fprintf(fileId, ['Monte Carlo points use adaptive error-count stopping: ' ...
    '%d errors or %.0f bits per SNR point. Smooth solid lines are the ' ...
    'exact BER of the same detector; they are not empirical fits.\n\n'], ...
    config.targetBitErrors, config.maxBitsPerPoint);
fprintf(fileId, 'Simulation points: %d  \n', height(results));
fprintf(fileId, 'Total symbols: %.0f  \n', sum(results.total_symbols));
fprintf(fileId, 'Total bits: %.0f  \n', sum(results.total_bits));
fprintf(fileId, 'Elapsed time: %.2f seconds  \n', elapsedSeconds);
clear cleanup;

fprintf('Simulation completed in %.2f seconds.\n', elapsedSeconds);
fprintf('BER figure: %s\n', pngPath);
fprintf('BER data: %s\n', csvPath);

%% Local functions
function tx = css_modulate(symbols, sf)
m = 2^sf;
symbols = double(symbols(:).');
if any(symbols < 0 | symbols >= m | symbols ~= floor(symbols))
    error('LoRaBasic:InvalidSymbol', ...
        'Symbols must be integers in [0, 2^SF-1].');
end
k = (0:m-1).';
baseUpChirp = exp(1i*2*pi*(k.^2/(2*m) - k/2));
tones = exp(1i*2*pi/m*(k*symbols));
tx = baseUpChirp .* tones;
end

function detected = css_demodulate(rx, sf)
m = 2^sf;
if isvector(rx)
    rx = rx(:);
end
if size(rx, 1) ~= m
    error('LoRaBasic:InvalidLength', ...
        'The waveform must contain 2^SF samples per column.');
end
reference = css_modulate(uint32(0), sf);
spectrum = fft(rx .* conj(reference), m, 1);
[~, peakIndex] = max(abs(spectrum).^2, [], 1);
detected = uint32(peakIndex-1);
end

function run_internal_checks()
rng(1207, 'twister');

for sf = 7:12
    m = 2^sf;
    if sf == 7
        symbols = uint32(0:m-1);
    else
        symbols = randi([0, m-1], 1, 100, 'uint32');
    end
    tx = css_modulate(symbols, sf);
    assert(abs(mean(abs(tx(:)).^2)-1) < 1e-12, ...
        'Unit-power check failed for SF%d.', sf);
    detected = css_demodulate(tx, sf);
    assert(isequal(detected, symbols), ...
        'Noiseless detection failed for SF%d.', sf);
end

snrDb = -12;
expectedVariance = 10^(-snrDb/10);
numberSamples = 300000;
noise = sqrt(expectedVariance/2) .* ...
    (randn(numberSamples, 1) + 1i*randn(numberSamples, 1));
relativeError = abs(mean(abs(noise).^2)/expectedVariance-1);
assert(relativeError < 0.01, 'Complex AWGN power check failed.');
end

function result = simulate_ber_point(sf, snrDb, config)
m = 2^sf;
snrLinear = 10^(snrDb/10);
correctBinMean = sqrt(m*snrLinear);
numberWrongBins = m-1;
snrIndex = round((snrDb-config.snrDb(1))/config.snrStepDb);
rng(config.randomSeed + 1000*sf + snrIndex, 'twister');

bitErrors = 0;
symbolErrors = 0;
totalBits = 0;
totalSymbols = 0;
batchCount = 0;

while bitErrors < config.targetBitErrors && ...
        totalBits < config.maxBitsPerPoint
    remainingSymbols = floor( ...
        (config.maxBitsPerPoint-totalBits)/sf);
    if remainingSymbols < 1
        break;
    end
    numberSymbols = min(config.batchSymbols, remainingSymbols);

    transmitted = randi([0, m-1], numberSymbols, 1, 'uint32');
    correctNoise = (randn(numberSymbols, 1) + ...
        1i*randn(numberSymbols, 1))/sqrt(2);
    correctPower = abs(correctBinMean + correctNoise).^2;

    logUniform = log(rand(numberSymbols, 1));
    maxWrongPower = -log( ...
        -expm1(logUniform/numberWrongBins));
    errorMask = maxWrongPower > correctPower;
    errorsThisBatch = nnz(errorMask);
    symbolErrors = symbolErrors + errorsThisBatch;

    if errorsThisBatch > 0
        transmittedErrors = transmitted(errorMask);
        wrongBase = randi([0, m-2], ...
            errorsThisBatch, 1, 'uint32');
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
    batchCount = batchCount + 1;
end

if bitErrors == 0
    ber = NaN;
    isUpperBound = true;
else
    ber = bitErrors/totalBits;
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
    'is_upper_bound', isUpperBound, ...
    'symbol_errors', symbolErrors, ...
    'total_symbols', totalSymbols, ...
    'ser', ser, ...
    'monte_carlo_batches', batchCount, ...
    'seed', config.randomSeed + 1000*sf + snrIndex, ...
    'stop_reason', stopReason);
end

function ber = css_theoretical_ber(sf, snrDb)
m = 2^sf;
snrDb = snrDb(:);
ber = zeros(size(snrDb));

for index = 1:numel(snrDb)
    noncentrality = m*10^(snrDb(index)/10);
    integrationLimit = max(50, noncentrality + ...
        20*sqrt(noncentrality+1) + 50);
    integrand = @(power) conditional_error(power, m) .* ...
        noncentral_power_pdf(power, noncentrality);
    ser = integral(integrand, 0, integrationLimit, ...
        'RelTol', 1e-8, 'AbsTol', 1e-12);
    ber(index) = ser*m/(2*(m-1));
end
end

function probability = conditional_error(power, m)
probability = -expm1((m-1).*log1p(-exp(-power)));
end

function density = noncentral_power_pdf(power, noncentrality)
argument = 2*sqrt(noncentrality.*power);
density = exp(-(sqrt(power)-sqrt(noncentrality)).^2) .* ...
    besseli(0, argument, 1);
end
