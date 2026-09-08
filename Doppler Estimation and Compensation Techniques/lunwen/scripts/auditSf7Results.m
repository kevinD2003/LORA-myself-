%AUDITSF7RESULTS Machine-check the completed SF=7 Monte Carlo artifacts.

projectRoot = fileparts(fileparts(mfilename('fullpath')));
resultsFolder = fullfile(projectRoot, 'results');
addpath(fullfile(projectRoot, 'src'));
case1 = readtable(fullfile(resultsFolder, 'case1_sf7.csv'), ...
    'TextType', 'string');
case2 = readtable(fullfile(resultsFolder, 'case2_sf7.csv'), ...
    'TextType', 'string');
strategies = ["no_doppler", "point", "midamble_point"];
expectedSnrDb = (-15:-6).';

assert(height(case1) == 30 && height(case2) == 30);
assert(~any(case1.fittedOrTuned) && ~any(case2.fittedOrTuned));
assert(all(case1.packets >= 5000) && all(case2.packets >= 5000));
assert(all(case1.symbolErrors >= 1500) && ...
    all(case2.symbolErrors >= 1500));
for strategy = strategies
    case1Rows = sortrows(case1(case1.strategy == strategy, :), 'snrDb');
    case2Rows = sortrows(case2(case2.strategy == strategy, :), 'snrDb');
    assert(isequal(case1Rows.snrDb, expectedSnrDb));
    assert(isequal(case2Rows.snrDb, expectedSnrDb));
    assert(all(diff(case1Rows.ser) <= 0));
    assert(all(diff(case2Rows.ser) <= 0));
end

case1End = case1(case1.snrDb == -6, :);
case2End = case2(case2.snrDb == -6, :);
case1Point = case1End.ser(case1End.strategy == "point");
case1Midamble = case1End.ser( ...
    case1End.strategy == "midamble_point");
case2Point = case2End.ser(case2End.strategy == "point");
case2Midamble = case2End.ser( ...
    case2End.strategy == "midamble_point");
assert(abs(case1Point-case1Midamble) < 0.01);
assert(abs(case2Point-case2Midamble) < 0.01);

referenceTable = readtable(fullfile(projectRoot, 'reference', ...
    'paperEndpointAcceptance.csv'), 'TextType', 'string');
paperEvaluation = evaluatePaperAgreement( ...
    [case1; case2], referenceTable, 7);
writetable(paperEvaluation.comparisons, fullfile(resultsFolder, ...
    'paper_agreement_sf7.csv'));

audit = struct();
audit.dataIntegrityPassed = true;
audit.paperAgreementPassed = paperEvaluation.passed;
if audit.paperAgreementPassed
    audit.state = "paper_match_passed";
else
    audit.state = "data_integrity_passed_paper_endpoint_mismatch";
end
audit.spreadingFactor = 7;
audit.case1Rows = height(case1);
audit.case2Rows = height(case2);
audit.minimumPacketsPerPoint = min([case1.packets; case2.packets]);
audit.minimumErrorsPerPoint = min([ ...
    case1.symbolErrors; case2.symbolErrors]);
audit.allFittedOrTunedFlagsFalse = true;
audit.case1PointMinus6 = case1Point;
audit.case1MidamblePointMinus6 = case1Midamble;
audit.case2PointMinus6 = case2Point;
audit.case2MidamblePointMinus6 = case2Midamble;
audit.combinedFigureExists = isfile(fullfile(resultsFolder, ...
    'figure10_11_sf7_midamble_point.png'));
audit.paperAgreementMatchCount = paperEvaluation.matchCount;
audit.paperAgreementReferenceCount = paperEvaluation.referenceCount;
assert(audit.combinedFigureExists);

statusPath = fullfile(resultsFolder, 'sf7_result_audit.json');
fileId = fopen(statusPath, 'w');
assert(fileId >= 0);
closeFile = onCleanup(@() fclose(fileId));
fprintf(fileId, '%s', jsonencode(audit));
fprintf('SF=7 data audit completed with state %s: %s\n', ...
    audit.state, statusPath);
