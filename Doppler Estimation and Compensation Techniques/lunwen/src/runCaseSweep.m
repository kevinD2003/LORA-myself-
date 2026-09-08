function resultTable = runCaseSweep( ...
    cfg, caseName, snrValuesDb, limits, outputCsv)
%RUNCASESWEEP Run all three locked curves and save after every SNR point.

arguments
    cfg (1,1) struct
    caseName (1,1) string
    snrValuesDb double {mustBeFinite}
    limits (1,1) struct
    outputCsv (1,1) string
end

strategies = ["no_doppler", "point", "midamble_point"];
results = struct([]);
rowIndex = 0;
for strategy = strategies
    for snrDb = snrValuesDb
        rowIndex = rowIndex + 1;
        current = simulateSerPoint( ...
            cfg, caseName, strategy, snrDb, limits);
        if rowIndex == 1
            results = current;
        else
            results(rowIndex) = current;
        end
        resultTable = writeSerResults(results, outputCsv);
        fprintf(['%s  %-16s  SNR=%6.1f dB  SER=%9.6g  ', ...
            'errors=%d  symbols=%d  packets=%d\n'], ...
            current.caseName, current.strategy, current.snrDb, ...
            current.ser, current.symbolErrors, ...
            current.totalSymbols, current.packets);
    end
end
end
