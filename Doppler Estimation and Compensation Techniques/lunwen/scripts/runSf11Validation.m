%RUNSF11VALIDATION Execute formula-derived SF=11 validation gates.

projectRoot = fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(projectRoot, 'scripts'));
addpath(fullfile(projectRoot, 'config'));
addpath(fullfile(projectRoot, 'src'));
cfg = paperSf11Config();
report = struct();

testResults = runProjectTests(string(fullfile(projectRoot, 'tests')));
disp(testResults);
if any([testResults.Failed]) || any([testResults.Incomplete])
    error('runSf11Validation:TestFailure', ...
        'At least one MATLAB unit test failed or was incomplete.');
end

report.matlabRelease = version('-release');
report.spreadingFactor = cfg.radio.spreadingFactor;
report.ldroEnabled = cfg.radio.ldro;
report.dataAlphabetSize = cfg.radio.dataAlphabetSize;
report.dataBinSpacing = cfg.radio.dataBinSpacing;
report.midambleSpacingDerivation = ...
    cfg.paper.midambleSpacingDerivation;
report.loraPhy = validateLoraNoiseless(cfg, 10000);
report.pointEstimator = validatePointEstimator(cfg);
report.doppler = dopplerLandmarks(cfg);
report.frame = validateFrameProtocol(cfg);
report.testsPassed = all([testResults.Passed]);
if ~report.loraPhy.passed || ~report.pointEstimator.passed
    error('runSf11Validation:GateFailure', ...
        'An SF=11 signal-processing validation gate failed.');
end
report.paperFrameMatched = report.frame.passed;

resultsFolder = fullfile(projectRoot, 'results');
case1Trace = buildTrackingTrace(cfg, "case1");
case2Trace = buildTrackingTrace(cfg, "case2");
writeTrackingTrace(case1Trace, ...
    fullfile(resultsFolder, 'case1_sf11_tracking.csv'));
writeTrackingTrace(case2Trace, ...
    fullfile(resultsFolder, 'case2_sf11_tracking.csv'));
plotTrackingTrace(case1Trace, ...
    fullfile(resultsFolder, 'case1_sf11_tracking.png'));
plotTrackingTrace(case2Trace, ...
    fullfile(resultsFolder, 'case2_sf11_tracking.png'));
report.tracking.case1FrameChangeHz = ...
    case1Trace.trueDopplerHz(end)-case1Trace.trueDopplerHz(1);
report.tracking.case2FrameChangeHz = ...
    case2Trace.trueDopplerHz(end)-case2Trace.trueDopplerHz(1);
report.tracking.case1UpdateCount = numel(case1Trace.updateTimeS)-1;
report.tracking.case2UpdateCount = numel(case2Trace.updateTimeS)-1;

reportPath = fullfile(resultsFolder, 'sf11_validation.json');
fileId = fopen(reportPath, 'w');
assert(fileId >= 0, 'Cannot write sf11_validation.json.');
closeReport = onCleanup(@() fclose(fileId));
fprintf(fileId, '%s', jsonencode(report));
if report.paperFrameMatched
    fprintf('SF=11 validation passed. Report: %s\n', reportPath);
else
    warning('runSf11Validation:DerivedFrameUnresolved', ...
        'Signal gates passed, but derived frame timing is unresolved.');
end
