function ser = senloraSymmetricV8AwgnTheory(sf,snrDb)
%SENLORASYMMETRICV8AWGNTHEORY Exact noncoherent orthogonal FFT-bin SER.
arguments
    sf (1,1) double {mustBeInteger,mustBePositive}
    snrDb (:,1) double {mustBeFinite}
end
m = 2^sf;
ser = zeros(size(snrDb));
for k = 1:numel(snrDb)
    lambda = m*10^(snrDb(k)/10);
    upper = max(80,lambda+24*sqrt(lambda+1)+60);
    density = @(r)exp(-(sqrt(r)-sqrt(lambda)).^2).*besseli(0,2*sqrt(lambda*r),1);
    error = @(r)-expm1((m-1).*log1p(-exp(-r)));
    ser(k) = integral(@(r)error(r).*density(r),0,upper,'RelTol',1e-9,'AbsTol',1e-13);
end
end
