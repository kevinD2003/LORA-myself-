function seed = seedForRun(cfg, caseName, strategy, snrDb)
%SEEDFORRUN Derive a deterministic twister seed for one Monte Carlo point.
% By default the same case/strategy/SNR uses common random numbers across
% spreading factors. Set commonRandomNumbersAcrossSf=false for independence.

arguments
    cfg (1,1) struct
    caseName (1,1) string
    strategy (1,1) string
    snrDb (1,1) double {mustBeFinite}
end

caseName = string(caseName);
strategy = string(strategy);
switch caseName
    case "case1"
        caseCode = 1;
    case "case2"
        caseCode = 2;
    otherwise
        error('seedForRun:UnknownCase', 'Unknown case: %s', caseName);
end
switch strategy
    case "no_doppler"
        strategyCode = 1;
    case "point"
        strategyCode = 2;
    case "midamble_point"
        strategyCode = 3;
    otherwise
        error('seedForRun:UnknownStrategy', ...
            'Unknown strategy: %s', strategy);
end
if isfield(cfg.monteCarlo, 'commonRandomNumbersAcrossStrategies') && ...
        cfg.monteCarlo.commonRandomNumbersAcrossStrategies
    strategyCode = 0;
end
snrCode = round((snrDb + 100)*10);
seed = mod(cfg.monteCarlo.randomSeed + caseCode*1000003 + ...
    strategyCode*100003 + snrCode*37, 2^32 - 1);
if ~cfg.monteCarlo.commonRandomNumbersAcrossSf
    seed = mod(seed + cfg.radio.spreadingFactor*1009, 2^32 - 1);
end
seed = double(floor(seed));
end
