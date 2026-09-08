function ber = theoreticalLoRaBerAwgn(sf, sampleSnrDb)
%THEORETICALLORABERAWGN Exact noncoherent orthogonal-MFSK BER in AWGN.
%
% sampleSnrDb is the time-domain sample SNR. Dechirp and an M-point unitary
% FFT yield Es/N0 = M * sampleSNR for M=2^SF orthogonal bins.

arguments
    sf (1,1) double {mustBeInteger, mustBePositive}
    sampleSnrDb (:,1) double
end

numBins = 2 ^ sf;
ber = zeros(size(sampleSnrDb));

for idx = 1:numel(sampleSnrDb)
    gamma = numBins * 10 ^ (sampleSnrDb(idx) / 10);
    integrand = @(x) exp(-(sqrt(x) - sqrt(gamma)) .^ 2) .* ...
        besseli(0, 2 * sqrt(gamma .* x), 1) .* ...
        (-expm1(-x)) .^ (numBins - 1);
    probabilityCorrect = integral(integrand, 0, Inf, ...
        "RelTol", 1e-9, "AbsTol", 1e-12);
    symbolErrorRate = max(0, min(1, 1 - probabilityCorrect));
    ber(idx) = numBins / (2 * (numBins - 1)) * symbolErrorRate;
end

end
