function upchirp = loraBaseUpchirp(sf)
%LORABASEUPCHIRP Generate one unit-power discrete LoRa base upchirp.

arguments
    sf (1,1) double {mustBeInteger, mustBePositive}
end

numSamples = 2 ^ sf;
sampleIndex = 0:(numSamples - 1);
phase = pi * (sampleIndex .^ 2 / numSamples - sampleIndex);
upchirp = exp(1i * phase);

end
