function chirp = loraPureUpchirp(spreadingFactor)
%LORAPUREUPCHIRP Generate one unit-power LoRa pure upchirp.
% The sample rate equals the bandwidth, so there is one complex sample per
% chip and N = 2^SF samples per symbol.

arguments
    spreadingFactor (1,1) double {mustBeInteger, mustBeInRange(spreadingFactor, 5, 12)}
end

validateattributes(spreadingFactor, {'numeric'}, ...
    {'scalar', 'integer', '>=', 5, '<=', 12});
numSamples = 2^spreadingFactor;
sampleIndex = (0:numSamples-1).';
chirp = exp(1j*pi*(sampleIndex.^2/numSamples - sampleIndex));
end
