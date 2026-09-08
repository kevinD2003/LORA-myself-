function ber = senloraTheoreticalBerAwgn(sf, snrDb)
%SENLORATHEORETICALBERAWGN Orthogonal-MFSK AWGN reference.
arguments
    sf (1,1) double {mustBeInteger,mustBePositive}
    snrDb (:,1) double
end
numBins = 2^sf;
ber = zeros(size(snrDb));
for idx = 1:numel(snrDb)
    gamma = numBins*10^(snrDb(idx)/10);
    % For SF11 the high-SNR integral is concentrated in a very narrow
    % region around x=gamma.  Above this threshold use the leading exact
    % series term rather than returning zero.  The omitted second term is
    % below 0.3% of the first at gamma=80 and decreases thereafter.
    if gamma > 80
        ber(idx) = numBins/4*exp(-gamma/2);
        continue
    end
    integrand = @(x) exp(-(sqrt(x)-sqrt(gamma)).^2).* ...
        besseli(0,2*sqrt(gamma.*x),1).* ...
        (-expm1(-x)).^(numBins-1);
    upperLimit = gamma + 20*sqrt(gamma) + 50;
    probabilityCorrect = integral(integrand,0,upperLimit, ...
        "RelTol",1e-6,"AbsTol",1e-10);
    ser = max(0,min(1,1-probabilityCorrect));
    ber(idx) = numBins/(2*(numBins-1))*ser;
end
end
