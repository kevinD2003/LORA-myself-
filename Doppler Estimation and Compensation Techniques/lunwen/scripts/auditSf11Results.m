%AUDITSF11RESULTS Machine-check the completed derived SF=11 artifacts.

projectRoot = fileparts(fileparts(mfilename('fullpath')));
resultsFolder = fullfile(projectRoot, 'results');
addpath(fullfile(projectRoot, 'config'));
addpath(fullfile(projectRoot, 'src'));
case1 = readtable(fullfile(resultsFolder, 'case1_sf11.csv'), ...
    'TextType', 'string');
case2 = readtable(fullfile(resultsFolder, 'case2_sf11.csv'), ...
    'TextType', 'string');
strategies = ["no_doppler", "point", "midamble_point"];
expectedSnrDb = (-27:-18).';

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

case1End = case1(case1.snrDb == -18, :);
case2End = case2(case2.snrDb == -18, :);
case1Point = case1End.ser(case1End.strategy == "point");
case1Midamble = case1End.ser( ...
    case1End.strategy == "midamble_point");
case2Point = case2End.ser(case2End.strategy == "point");
case2Midamble = case2End.ser( ...
    case2End.strategy == "midamble_point");
assert(abs(case1Point-case1Midamble) < 0.02);
assert(case2Midamble < 0.5*case2Point);

cfg = paperSf11Config();
derivation = cfg.paper.midambleSpacingDerivation;
assert(derivation.selectedIntegerSpacing == 12);
assert(~derivation.fittedOrTuned);

audit = struct();
audit.state = "derived_experiment_passed";
audit.dataIntegrityPassed = true;
audit.paperAgreementApplicable = false;
audit.spreadingFactor = 11;
audit.midambleSpacing = derivation.selectedIntegerSpacing;
audit.spacingSource = derivation.source;
audit.spacingFittedOrTuned = derivation.fittedOrTuned;
audit.case1Rows = height(case1);
audit.case2Rows = height(case2);
audit.minimumPacketsPerPoint = min([case1.packets; case2.packets]);
audit.minimumErrorsPerPoint = min([ ...
    case1.symbolErrors; case2.symbolErrors]);
audit.allFittedOrTunedFlagsFalse = true;
audit.case1PointMinus18 = case1Point;
audit.case1MidamblePointMinus18 = case1Midamble;
audit.case2PointMinus18 = case2Point;
audit.case2MidamblePointMinus18 = case2Midamble;
audit.case2RelativeImprovement = ...
    1-case2Midamble/case2Point;
audit.combinedFigureExists = isfile(fullfile(resultsFolder, ...
    'sf11_midamble_point_case1_case2.png'));
assert(audit.combinedFigureExists);

statusPath = fullfile(resultsFolder, 'sf11_result_audit.json');
fileId = fopen(statusPath, 'w');
assert(fileId >= 0);
closeFile = onCleanup(@() fclose(fileId));
fprintf(fileId, '%s', jsonencode(audit));
fprintf('Full SF=11 audit passed: %s\n', statusPath);
