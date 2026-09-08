function result = satelliteFig3AdaptiveRateReplaySenLoRaDecode( ...
        rxSymbols,config,knownWaveformBins)
%SATELLITEFIG3ADAPTIVERATEREPLAYSENLORADECODE Physical-prior SenLoRa track.
%   Every SNR uses the same receiver path.  The known orbit plus coarse
%   preamble CFO supplies one bootstrap rate; payload soft-Hamming evidence
%   only admits rolling virtual pilots and never selects among rate tracks.
result = satelliteFig3RateReplaySenLoRaDecode( ...
    rxSymbols,config,knownWaveformBins);
result.rateReplay.triggered = true;
result.rateReplay.triggerReason = 'single_orbit_prior_track';
result.rateReplay.baselinePilotCount = NaN;
result.rateReplay.baselineEstimatedSnrDb = NaN;
end
