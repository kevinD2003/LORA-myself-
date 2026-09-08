%RUNSTAGE1VALIDATION Execute all pre-Monte-Carlo paper reproduction gates.

projectRoot = fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(projectRoot, 'scripts'));
addpath(fullfile(projectRoot, 'config'));
addpath(fullfile(projectRoot, 'src'));
cfg = paperSf12Config();
report = struct();

testResults = runProjectTests(string(fullfile(projectRoot, 'tests')));
disp(testResults);
if any([testResults.Failed]) || any([testResults.Incomplete])
    error('runStage1Validation:TestFailure', ...
        'At least one MATLAB unit test failed or was incomplete.');
end

report.matlabRelease = version('-release');
report.ldroEnabled = cfg.radio.ldro;
report.dataAlphabetSize = cfg.radio.dataAlphabetSize;
report.dataBinSpacing = cfg.radio.dataBinSpacing;
report.loraPhy = validateLoraNoiseless(cfg, 10000);
report.pointEstimator = validatePointEstimator(cfg);
report.doppler = dopplerLandmarks(cfg);
report.frame = validateFrameProtocol(cfg);
report.testsPassed = all([testResults.Passed]);
if ~report.loraPhy.passed || ~report.pointEstimator.passed
    error('runStage1Validation:GateFailure', ...
        'A signal-processing validation gate failed.');
end
report.paperFrameMatched = report.frame.passed;

resultsFolder = fullfile(projectRoot, 'results');
if ~isfolder(resultsFolder)
    mkdir(resultsFolder);
end
case1Trace = buildTrackingTrace(cfg, "case1");
case2Trace = buildTrackingTrace(cfg, "case2");
writeTrackingTrace(case1Trace, ...
    fullfile(resultsFolder, 'case1_tracking.csv'));
writeTrackingTrace(case2Trace, ...
    fullfile(resultsFolder, 'case2_tracking.csv'));
plotTrackingTrace(case1Trace, ...
    fullfile(resultsFolder, 'case1_tracking.png'));
plotTrackingTrace(case2Trace, ...
    fullfile(resultsFolder, 'case2_tracking.png'));
report.tracking.case1FrameChangeHz = ...
    case1Trace.trueDopplerHz(end)-case1Trace.trueDopplerHz(1);
report.tracking.case2FrameChangeHz = ...
    case2Trace.trueDopplerHz(end)-case2Trace.trueDopplerHz(1);
report.tracking.case1UpdateCount = numel(case1Trace.updateTimeS)-1;
report.tracking.case2UpdateCount = numel(case2Trace.updateTimeS)-1;

reportPath = fullfile(resultsFolder, 'stage1_validation.json');
fileId = fopen(reportPath, 'w');
if fileId < 0
    error('runStage1Validation:CannotWriteReport', ...
        'Cannot open %s for writing.', reportPath);
end
closeReport = onCleanup(@() fclose(fileId));
fprintf(fileId, '%s', jsonencode(report));
if report.paperFrameMatched
    fprintf('Stage 1 validation passed. Report: %s\n', reportPath);
else
    warning('runStage1Validation:PaperFrameUnresolved', ...
        'Signal gates passed, but paper Midamble ToA remains unresolved.');
end
