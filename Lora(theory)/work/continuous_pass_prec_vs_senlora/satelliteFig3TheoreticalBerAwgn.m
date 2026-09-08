function ber = satelliteFig3TheoreticalBerAwgn(sf,snrDb)
%SATELLITEFIG3THEORETICALBERAWGN Uncoded orthogonal-CSS AWGN reference.
%   This is an analytical uncoded reference.  The simulated payload BER is
%   measured after Hamming(7,4) decoding and must be labelled separately.

arguments
    sf (1,1) double {mustBeInteger,mustBePositive}
    snrDb (:,1) double
end

binCount = 2^sf;
ber = zeros(size(snrDb));
for index = 1:numel(snrDb)
    symbolSnr = binCount*10^(snrDb(index)/10);
    if symbolSnr > 80
        ber(index) = binCount/4*exp(-symbolSnr/2);
        continue
    end
    integrand = @(x) exp(-(sqrt(x)-sqrt(symbolSnr)).^2).* ...
        besseli(0,2*sqrt(symbolSnr.*x),1).* ...
        (-expm1(-x)).^(binCount-1);
    upperLimit = symbolSnr+20*sqrt(symbolSnr)+50;
    probabilityCorrect = integral(integrand,0,upperLimit, ...
        'RelTol',1e-6,'AbsTol',1e-10);
    symbolErrorRate = max(0,min(1,1-probabilityCorrect));
    ber(index) = binCount/(2*(binCount-1))*symbolErrorRate;
end
end
