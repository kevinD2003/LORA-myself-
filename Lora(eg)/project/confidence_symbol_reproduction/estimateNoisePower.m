function noisePower = estimateNoisePower(preambleFft)
%ESTIMATENOISEPOWER Estimate N0 from nonzero preamble FFT bins.

arguments
    preambleFft (:,:) double
end

powerSpectrum = abs(preambleFft) .^ 2;
if size(powerSpectrum, 1) > 1
    powerSpectrum = mean(powerSpectrum, 1);
end

if numel(powerSpectrum) < 2
    error("SenLoRa:InvalidPreamble", ...
        "preambleFft must contain at least two FFT bins.");
end

noisePower = mean(powerSpectrum(2:end));
noisePower = max(noisePower, eps);

end

