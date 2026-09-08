function [received, noiseVariance] = receivedDechirpedBatch( ...
    dopplerTemplate, channelCoefficient, estimateHz, snrDb, cfg)
%RECEIVEDDECHIRPEDBATCH Form the sufficient statistic for FFT detection.
% Doppler template is the integrated phase within the current chirp. A
% symbol-zero tone is sufficient because every LoRa symbol is a circular
% FFT-bin shift and the complex AWGN distribution is shift invariant.

arguments
    dopplerTemplate double
    channelCoefficient double
    estimateHz double
    snrDb (1,1) double {mustBeFinite}
    cfg (1,1) struct
end

numSamples = cfg.radio.samplesPerSymbol;
sampleTimeS = (0:numSamples-1).'/cfg.radio.sampleRateHz;
estimateHz = reshape(estimateHz, 1, []);
if string(cfg.channel.model) == "rician_sample"
    channelCoefficient = drawChannelCoefficient( ...
        cfg, numel(estimateHz), numSamples);
else
    channelCoefficient = reshape(channelCoefficient, 1, []);
end
correction = exp(-1j*2*pi*sampleTimeS*estimateHz);
signal = dopplerTemplate.*correction.*channelCoefficient;
[received, noiseVariance] = applyUnitPowerAwgn(signal, snrDb, cfg);
end
