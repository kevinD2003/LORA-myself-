function bank = makePhaseRotationBank(sf, candidateOffsets)
%MAKEPHASEROTATIONBANK Precompute PREC-style phase rotations.

arguments
    sf (1,1) double {mustBeInteger, mustBePositive}
    candidateOffsets (:,1) double
end

numSamples = 2 ^ sf;
sampleIndex = 0:(numSamples - 1);
bank = exp(-1i * 2 * pi * candidateOffsets * sampleIndex / numSamples);

end
