function chirp = loraPureDownchirp(spreadingFactor)
%LORAPUREDOWNCHIRP Generate the complex conjugate of a pure upchirp.

arguments
    spreadingFactor (1,1) double {mustBeInteger, mustBeInRange(spreadingFactor, 5, 12)}
end

chirp = conj(loraPureUpchirp(spreadingFactor));
end
