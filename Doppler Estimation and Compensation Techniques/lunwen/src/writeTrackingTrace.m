function traceTable = writeTrackingTrace(trace, outputCsv)
%WRITETRACKINGTRACE Save the noise-free algorithm diagnostic.

arguments
    trace (1,1) struct
    outputCsv (1,1) string
end

traceTable = table(trace.dataTimeS(:), trace.trueDopplerHz(:), ...
    trace.pointEstimateHz(:), trace.midamblePointEstimateHz(:), ...
    'VariableNames', {'dataTimeS', 'trueDopplerHz', ...
    'pointEstimateHz', 'midamblePointEstimateHz'});
outputFolder = fileparts(outputCsv);
if ~isfolder(outputFolder)
    mkdir(outputFolder);
end
writetable(traceTable, outputCsv);
end
