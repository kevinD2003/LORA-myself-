function resultTable = runReproductionCase( ...
    cfg, caseName, snrValuesDb, limits, resultsFolder, suffix)
%RUNREPRODUCTIONCASE Run, save and plot one spreading-factor case.

arguments
    cfg (1,1) struct
    caseName (1,1) string
    snrValuesDb double {mustBeFinite}
    limits (1,1) struct
    resultsFolder (1,1) string
    suffix (1,1) string
end

caseName = string(caseName);
suffix = string(suffix);
if caseName == "case1"
    caseLabel = "Case 1";
elseif caseName == "case2"
    caseLabel = "Case 2";
else
    error('runReproductionCase:UnknownCase', ...
        'Unknown case: %s', caseName);
end
spreadingFactor = string(cfg.radio.spreadingFactor);
baseName = caseName + "_sf" + spreadingFactor + suffix;
outputCsv = fullfile(resultsFolder, baseName + ".csv");
outputPng = fullfile(resultsFolder, baseName + ".png");
resultTable = runCaseSweep( ...
    cfg, caseName, snrValuesDb, limits, outputCsv);
plotSerResults(outputCsv, outputPng, ...
    caseLabel + " - SF = " + spreadingFactor, cfg);
fprintf('Wrote %s\n', outputCsv);
fprintf('Wrote %s\n', outputPng);
end
