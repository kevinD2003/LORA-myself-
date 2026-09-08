function sf12ValidateConfig(cfg)
%SF12VALIDATECONFIG Reject accidental use of non-paper or SF11 settings.

assert(cfg.radio.sf == 12 && cfg.radio.bandwidthHz == 125e3);
assert(cfg.radio.sampleRateHz == cfg.radio.bandwidthHz);
assert(cfg.radio.carrierFrequencyHz == 868e6);
assert(cfg.radio.ldro && cfg.radio.dataBinSpacing == 4);
assert(cfg.frame.payloadSymbolCount == 23 && cfg.frame.cr == 1);
assert(cfg.frame.midambleSpacing == 3);
assert(cfg.channel.ricianKDb == 10);
assert(cfg.orbit.case1StartTimeSec == -366);
assert(cfg.orbit.case2StartTimeSec == 0);
assert(~cfg.provenance.fittedOrTuned);
end
