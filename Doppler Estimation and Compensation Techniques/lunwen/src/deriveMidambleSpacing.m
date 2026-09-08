function derivation = deriveMidambleSpacing( ...
    targetSf, referenceSf, referenceSpacing, cfg)
%DERIVEMIDAMBLESPACING Apply paper Eq. (19)-(20) SF scaling.
% For fixed B, Doppler rate, tolerance and equal LDRO state,
% n_int is proportional to 2^(-2*SF).

arguments
    targetSf (1,1) double {mustBeInteger, mustBePositive}
    referenceSf (1,1) double {mustBeInteger, mustBePositive}
    referenceSpacing (1,1) double {mustBeInteger, mustBePositive}
    cfg (1,1) struct
end

scaleFactor = 2^(2*(referenceSf-targetSf));
exactSpacing = referenceSpacing*scaleFactor;
landmarks = dopplerLandmarks(cfg);
dopplerRateHzS = abs(landmarks.rateAtZeroHzS);
toleranceFactor = referenceSpacing*dopplerRateHzS* ...
    2^(2*referenceSf)/(cfg.radio.bandwidthHz^2);

derivation.targetSf = targetSf;
derivation.referenceSf = referenceSf;
derivation.referenceSpacing = referenceSpacing;
derivation.scaleFactor = scaleFactor;
derivation.exactSpacing = exactSpacing;
derivation.selectedIntegerSpacing = round(exactSpacing);
derivation.case2DopplerRateHzS = dopplerRateHzS;
derivation.impliedToleranceFactor = toleranceFactor;
derivation.source = "Paper Eq. (19)-(20), anchored to SF=12 n_int=3";
derivation.fittedOrTuned = false;
end
