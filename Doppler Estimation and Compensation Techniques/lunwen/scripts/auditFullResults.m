%AUDITFULLRESULTS Machine-check the completed SF=12 Monte Carlo artifacts.

projectRoot = fileparts(fileparts(mfilename('fullpath')));
resultsFolder = fullfile(projectRoot, 'results');
addpath(fullfile(projectRoot, 'src'));
case1 = readtable(fullfile(resultsFolder, 'case1_sf12.csv'), ...
    'TextType', 'string');
case2 = readtable(fullfile(resultsFolder, 'case2_sf12.csv'), ...
    'TextType', 'string');
expectedStrategies = ["no_doppler", "point", "midamble_point"];
expectedSnrDb = (-30:-21).';

assert(height(case1) == 30 && height(case2) == 30, ...
    'Each case must contain 30 rows.');
assert(~any(case1.fittedOrTuned) && ~any(case2.fittedOrTuned), ...
    'Fitted or tuned data are prohibited.');
assert(all(case1.packets >= 5000) && all(case2.packets >= 5000), ...
    'Every point must contain at least 5000 packets.');
assert(all(case1.symbolErrors >= 1500) && ...
    all(case2.symbolErrors >= 1500), ...
    'Every point must contain at least 1500 symbol errors.');
assert(all(case1.ser >= 0 & case1.ser <= 1) && ...
    all(case2.ser >= 0 & case2.ser <= 1), ...
    'SER must lie in [0,1].');

for strategy = expectedStrategies
    case1Rows = sortrows(case1(case1.strategy == strategy, :), 'snrDb');
    case2Rows = sortrows(case2(case2.strategy == strategy, :), 'snrDb');
    assert(isequal(case1Rows.snrDb, expectedSnrDb), ...
        'Case 1 SNR grid mismatch.');
    assert(isequal(case2Rows.snrDb, expectedSnrDb), ...
        'Case 2 SNR grid mismatch.');
    assert(all(diff(case1Rows.ser) <= 0), ...
        'Case 1 SER must be nonincreasing.');
    assert(all(diff(case2Rows.ser) <= 0), ...
        'Case 2 SER must be nonincreasing.');
end

case1AtMinus21 = case1(case1.snrDb == -21, :);
case2AtMinus21 = case2(case2.snrDb == -21, :);
case1Point = case1AtMinus21.ser( ...
    case1AtMinus21.strategy == "point");
case1Midamble = case1AtMinus21.ser( ...
    case1AtMinus21.strategy == "midamble_point");
case2Point = case2AtMinus21.ser( ...
    case2AtMinus21.strategy == "point");
case2Midamble = case2AtMinus21.ser( ...
    case2AtMinus21.strategy == "midamble_point");
assert(abs(case1Point-case1Midamble) < 0.02, ...
    'Case 1 Point and Midamble-Point should remain close.');
assert(case2Midamble < 0.2*case2Point, ...
    'Case 2 Midamble-Point must strongly improve over Point.');

referenceTable = readtable(fullfile(projectRoot, 'reference', ...
    'paperEndpointAcceptance.csv'), 'TextType', 'string');
paperEvaluation = evaluatePaperAgreement( ...
    [case1; case2], referenceTable, 12);
writetable(paperEvaluation.comparisons, fullfile(resultsFolder, ...
    'paper_agreement_sf12.csv'));

audit = struct();
audit.dataIntegrityPassed = true;
audit.paperAgreementPassed = paperEvaluation.passed;
if audit.paperAgreementPassed
    audit.state = "paper_match_passed";
else
    audit.state = "data_integrity_passed_paper_endpoint_mismatch";
end
audit.case1Rows = height(case1);
audit.case2Rows = height(case2);
audit.minimumPacketsPerPoint = min([case1.packets; case2.packets]);
audit.minimumErrorsPerPoint = min([ ...
    case1.symbolErrors; case2.symbolErrors]);
audit.allFittedOrTunedFlagsFalse = true;
audit.case1PointMinus21 = case1Point;
audit.case1MidamblePointMinus21 = case1Midamble;
audit.case2PointMinus21 = case2Point;
audit.case2MidamblePointMinus21 = case2Midamble;
audit.case2RelativeImprovement = ...
    1-case2Midamble/case2Point;
audit.combinedFigureExists = isfile(fullfile(resultsFolder, ...
    'figure10_11_sf12_midamble_point.png'));
audit.paperAgreementMatchCount = paperEvaluation.matchCount;
audit.paperAgreementReferenceCount = paperEvaluation.referenceCount;
assert(audit.combinedFigureExists, 'Combined figure is missing.');

statusPath = fullfile(resultsFolder, 'full_result_audit.json');
fileId = fopen(statusPath, 'w');
assert(fileId >= 0, 'Cannot write full_result_audit.json.');
closeFile = onCleanup(@() fclose(fileId));
fprintf(fileId, '%s', jsonencode(audit));
fprintf('SF=12 data audit completed with state %s: %s\n', ...
    audit.state, statusPath);
