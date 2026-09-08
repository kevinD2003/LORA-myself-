function resultTable = writeSerResults(results, outputCsv)
%WRITESERRESULTS Persist raw counts and SER without post-processing.

arguments
    results struct
    outputCsv (1,1) string
end

resultTable = struct2table(results);
if any(resultTable.fittedOrTuned)
    error('writeSerResults:FittedData', ...
        'Refusing to write results marked as fitted or tuned.');
end
outputFolder = fileparts(outputCsv);
if ~isfolder(outputFolder)
    mkdir(outputFolder);
end
writetable(resultTable, outputCsv);
end
