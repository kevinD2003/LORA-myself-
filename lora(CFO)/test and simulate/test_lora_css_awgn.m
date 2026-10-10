function tests = test_lora_css_awgn
%TEST_LORA_CSS_AWGN Unit tests for the uncoded LoRa CSS reproduction.
tests = functiontests(localfunctions);
end

function testNoiselessSymbolDetection(testCase)
rng(11, 'twister');
for sf = 7:12
    m = 2^sf;
    if sf == 7
        symbols = uint32(0:m-1);
    else
        symbols = randi([0, m-1], 1, 100, 'uint32');
    end
    detected = lora_css_demodulate(lora_css_modulate(symbols, sf), sf);
    verifyEqual(testCase, detected, symbols);
end
end

function testUnitAveragePower(testCase)
rng(12, 'twister');
for sf = 7:12
    symbols = randi([0, 2^sf-1], 1, 20, 'uint32');
    tx = lora_css_modulate(symbols, sf);
    measuredPower = mean(abs(tx(:)).^2);
    verifyLessThan(testCase, abs(measuredPower - 1), 1e-12);
end
end

function testFftPeakMapping(testCase)
for sf = 7:12
    m = 2^sf;
    symbols = uint32(unique([0, 1, floor(m/3), m-1]));
    tx = lora_css_modulate(symbols, sf);
    reference = lora_css_modulate(uint32(0), sf);
    spectrumPower = abs(fft(tx .* conj(reference), m, 1)).^2;
    [sortedPower, sortedIndex] = sort(spectrumPower, 1, 'descend');
    detected = uint32(sortedIndex(1, :) - 1);
    verifyEqual(testCase, detected, symbols);
    verifyGreaterThan(testCase, ...
        min(sortedPower(1, :) ./ max(sortedPower(2, :), realmin)), 1e12);
end
end

function testComplexAwgnPower(testCase)
rng(13, 'twister');
snrDb = -12;
noiseVariance = 10^(-snrDb/10);
numberSamples = 300000;
noise = sqrt(noiseVariance/2) * ...
    (randn(numberSamples, 1) + 1i*randn(numberSamples, 1));
measuredVariance = mean(abs(noise).^2);
relativeError = abs(measuredVariance/noiseVariance - 1);
verifyLessThan(testCase, relativeError, 0.01);
verifyLessThan(testCase, abs(mean(real(noise))), ...
    0.01*sqrt(noiseVariance));
verifyLessThan(testCase, abs(mean(imag(noise))), ...
    0.01*sqrt(noiseVariance));
end

function testBerDecreasesWithSnr(testCase)
config = lora_css_awgn_config();
config.targetBitErrors = 500;
config.maxBitsPerPoint = 1e6;
config.batchSymbols = 50000;

snrPoints = [-12, -10, -8];
ber = zeros(size(snrPoints));
for index = 1:numel(snrPoints)
    result = simulate_lora_css_awgn_point(7, snrPoints(index), config);
    ber(index) = result.plot_ber;
end
verifyGreaterThan(testCase, ber(1), ber(2));
verifyGreaterThan(testCase, ber(2), ber(3));
end

function testWaveformAndFftDomainAgreement(testCase)
sf = 7;
snrDb = -10;
m = 2^sf;
numberSymbols = 12000;
noiseVariance = 10^(-snrDb/10);

rng(14, 'twister');
symbols = randi([0, m-1], 1, numberSymbols, 'uint32');
tx = lora_css_modulate(symbols, sf);
noise = sqrt(noiseVariance/2) * ...
    (randn(size(tx)) + 1i*randn(size(tx)));
detected = lora_css_demodulate(tx + noise, sf);
waveformSer = mean(detected ~= symbols);

config = lora_css_awgn_config();
config.targetBitErrors = 1000;
config.maxBitsPerPoint = numberSymbols*sf;
config.batchSymbols = numberSymbols;
result = simulate_lora_css_awgn_point(sf, snrDb, config);
fftDomainSer = result.ser;

verifyLessThan(testCase, abs(waveformSer - fftDomainSer), 0.015);
end

function testTheoryAgreesWithMonteCarlo(testCase)
sf = 7;
snrDb = -10;
config = lora_css_awgn_config();
config.targetBitErrors = 5000;
config.maxBitsPerPoint = 2e6;
config.batchSymbols = 100000;

result = simulate_lora_css_awgn_point(sf, snrDb, config);
theoreticalBer = lora_css_theoretical_ber(sf, snrDb);
relativeError = abs(result.ber/theoreticalBer - 1);
verifyLessThan(testCase, relativeError, 0.05);
end
