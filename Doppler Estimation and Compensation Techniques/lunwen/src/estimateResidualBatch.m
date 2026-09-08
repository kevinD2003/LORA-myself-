function residualHz = estimateResidualBatch( ...
    dopplerTemplate, channelCoefficient, currentEstimateHz, snrDb, cfg)
%ESTIMATERESIDUALBATCH Estimate residual CFO after current compensation.

arguments
    dopplerTemplate double
    channelCoefficient double
    currentEstimateHz double
    snrDb (1,1) double {mustBeFinite}
    cfg (1,1) struct
end

estimatorSnrDb = snrDb;
model = string(cfg.receiver.midambleEstimatorModel);
if model == "legacy_snr_offset"
    estimatorSnrDb = snrDb + ...
        cfg.receiver.midambleEstimatorSnrOffsetDb;
elseif model ~= "physical"
    error('estimateResidualBatch:UnknownEstimatorModel', ...
        'Unknown Midamble estimator model: %s.', model);
end
[received, ~] = receivedDechirpedBatch( ...
    dopplerTemplate, channelCoefficient, currentEstimateHz, ...
    estimatorSnrDb, cfg);
residualHz = estimateFftFrequency(received, ...
    cfg.radio.sampleRateHz, cfg.radio.samplesPerSymbol* ...
    cfg.receiver.midambleEstimatorFftPaddingFactor);
end
