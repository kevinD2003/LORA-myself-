function coefficient = v4RicianCoefficient(config,seed,count)
%V4RICIANCOEFFICIENT Unit-mean-power packet-flat Rician K=10 dB samples.

arguments
    config (1,1) struct
    seed (1,1) double {mustBeInteger,mustBeNonnegative}
    count (1,1) double {mustBeInteger,mustBePositive} = 1
end
stream = RandStream('mt19937ar','Seed',seed);
kLinear = 10^(config.ricianKDb/10);
coefficient = sqrt(kLinear/(kLinear+1))+sqrt(1/(2*(kLinear+1)))*( ...
    randn(stream,count,1)+1i*randn(stream,count,1));
end

