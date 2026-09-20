function ser = theoretical_lora_ser(sf,snrDb,options)
%THEORETICAL_LORA_SER Exact noncoherent dechirp-FFT SER in complex AWGN.
% Each requested SNR is evaluated directly by quadrature.  No performance
% samples, curve fitting, offsets, or interpolation are used.

arguments
    sf (1,1) double {mustBeInteger,mustBePositive}
    snrDb (:,1) double
    options.RelTol (1,1) double = 1e-9
    options.AbsTol (1,1) double = 1e-14
end

m = 2^sf;
ser = zeros(size(snrDb));
for index = 1:numel(snrDb)
    noncentrality = m*10^(snrDb(index)/10);
    upperLimit = max(60,noncentrality+24*sqrt(noncentrality+1)+60);
    integrand = @(power) localConditionalError(power,m).* ...
        localNoncentralPowerPdf(power,noncentrality);
    value = integral(integrand,0,upperLimit, ...
        'RelTol',options.RelTol,'AbsTol',options.AbsTol);
    ser(index) = min(1,max(0,value));
end
end

function probability = localConditionalError(power,m)
% Stable form of 1-(1-exp(-power))^(m-1).
probability = -expm1((m-1).*log1p(-exp(-power)));
end

function density = localNoncentralPowerPdf(power,noncentrality)
% PDF of |sqrt(noncentrality)+CN(0,1)|^2.
argument = 2*sqrt(noncentrality.*power);
density = exp(-(sqrt(power)-sqrt(noncentrality)).^2).* ...
    besseli(0,argument,1);
end
