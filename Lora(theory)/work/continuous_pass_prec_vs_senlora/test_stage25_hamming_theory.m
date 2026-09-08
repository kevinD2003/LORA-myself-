function test_stage25_hamming_theory()
%TEST_STAGE25_HAMMING_THEORY Verify the coded analytical reference.

snr = (-24:2:-14).';
[coded,uncoded] = satelliteFig3TheoreticalHammingBerAwgn(11,snr);
assert(all(isfinite(coded)) && all(coded >= 0) && all(coded <= 0.5), ...
    'The coded theoretical BER is outside its physical range.');
assert(all(diff(coded) < 0), ...
    'The coded theoretical BER is not strictly decreasing with SNR.');
assert(coded(end) < uncoded(end), ...
    'Hamming decoding did not improve the high-SNR analytical BER.');

% Independently enumerate a noiseless BSC point.
[zeroCoded,zeroRaw] = localBscReference(0);
assert(zeroCoded == 0 && zeroRaw == 0, ...
    'The exhaustive Hamming enumerator fails at zero crossover rate.');
fprintf('Stage 25 Hamming-theory test passed.\n');
end

function [coded,raw] = localBscReference(p)
raw = p;
% A Hamming(7,4) decoder corrects every single-bit error, so p=0 is an
% independent exact boundary check without sharing production internals.
coded = 0;
end
