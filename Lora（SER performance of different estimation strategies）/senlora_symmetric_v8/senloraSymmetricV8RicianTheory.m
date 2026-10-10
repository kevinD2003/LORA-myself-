function ser = senloraSymmetricV8RicianTheory(sf,snrDb,kDb)
%SENLORASYMMETRICV8RICIANTHEORY Exact noncoherent SER with packet-flat Rice.
% The one-packet flat coefficient has E|h|^2=1 and a K-factor of kDb.
% Marginalizing its complex Gaussian scatter gives one noncentral-power
% integral. The curve is computed directly, without fitting simulations.

arguments
    sf (1,1) double {mustBeInteger,mustBePositive}
    snrDb (:,1) double {mustBeFinite}
    kDb (1,1) double {mustBeFinite}
end

m = 2^sf;
k = 10^(kDb/10);
ser = zeros(size(snrDb));
for index = 1:numel(snrDb)
    signalPower = m*10^(snrDb(index)/10);
    meanPower = signalPower*k/(k+1);
    variance = 1+signalPower/(k+1);
    upper = max(80,meanPower+24*sqrt(variance*(meanPower+variance))+60);
    integrand = @(power)localConditionalError(power,m).* ...
        localRicianPowerPdf(power,meanPower,variance);
    value = integral(integrand,0,upper, ...
        'RelTol',1e-9,'AbsTol',1e-13);
    ser(index) = min(1,max(0,value));
end
end

function probability = localConditionalError(power,m)
probability = -expm1((m-1).*log1p(-exp(-power)));
end

function density = localRicianPowerPdf(power,meanPower,variance)
argument = 2*sqrt(meanPower.*power)/variance;
density = exp(-(sqrt(power)-sqrt(meanPower)).^2/variance).* ...
    besseli(0,argument,1)/variance;
end
