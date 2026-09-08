function evaluation = evaluatePaperAgreement( ...
    resultTable, referenceTable, spreadingFactor)
%EVALUATEPAPERAGREEMENT Compare completed results with frozen paper bounds.
% Reference bounds are acceptance-only inputs and never enter simulation.

arguments
    resultTable table
    referenceTable table
    spreadingFactor (1,1) double {mustBeMember(spreadingFactor, [7, 12])}
end

referenceRows = referenceTable( ...
    referenceTable.spreadingFactor == spreadingFactor, :);
if isempty(referenceRows)
    error('evaluatePaperAgreement:MissingReference', ...
        'No paper acceptance rows exist for SF=%d.', spreadingFactor);
end

actualSer = nan(height(referenceRows), 1);
matchedRow = false(height(referenceRows), 1);
for index = 1:height(referenceRows)
    selected = resultTable.caseName == referenceRows.caseName(index) & ...
        resultTable.strategy == referenceRows.strategy(index) & ...
        resultTable.snrDb == referenceRows.snrDb(index);
    if nnz(selected) ~= 1
        error('evaluatePaperAgreement:ResultRowCount', ...
            'Expected one result for SF=%d %s %s SNR=%g.', ...
            spreadingFactor, referenceRows.caseName(index), ...
            referenceRows.strategy(index), referenceRows.snrDb(index));
    end
    actualSer(index) = resultTable.ser(selected);
    matchedRow(index) = actualSer(index) >= ...
        referenceRows.serLow(index) && actualSer(index) <= ...
        referenceRows.serHigh(index);
end

comparisons = referenceRows;
comparisons.actualSer = actualSer;
comparisons.withinAcceptanceRange = matchedRow;
evaluation.spreadingFactor = spreadingFactor;
evaluation.comparisons = comparisons;
evaluation.passed = all(matchedRow);
evaluation.matchCount = nnz(matchedRow);
evaluation.referenceCount = height(referenceRows);
evaluation.referenceUse = "acceptance_only_not_simulation";
end
