function estimate=v4TrackAProvisionalRate(anchor,candidate,parameters)
dt=candidate.measurementTimeSec-anchor.measurementTimeSec;
rate=(candidate.cfoCandidateBins-anchor.cfoBins)/dt;
estimate=struct('rateBinsPerSec',rate,'timeSeparationSec',dt, ...
    'finite',isfinite(rate)&&dt>0,'withinBound',isfinite(rate)&&dt>0&& ...
    abs(rate)<=parameters.maximumRateBinsPerSec);
end
