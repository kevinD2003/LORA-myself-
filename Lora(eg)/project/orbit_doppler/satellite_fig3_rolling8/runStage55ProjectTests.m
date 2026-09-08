function results = runStage55ProjectTests(options)
%RUNSTAGE55PROJECTTESTS Run every canonical Stage55 regression test.

arguments
    options.IncludeFuxianduibi (1,1) logical = true
end

stageFolder = fileparts(mfilename('fullpath'));
orbitFolder = fileparts(stageFolder);
projectFolder = fileparts(orbitFolder);
workspaceFolder = fileparts(projectFolder);
confidenceFolder = fullfile(projectFolder,'confidence_symbol_reproduction');
fuxianFolder = fullfile(workspaceFolder,'comparison_experiments', ...
    'stage55_three_method');

originalPath = path;
pathCleanup = onCleanup(@()path(originalPath)); %#ok<NASGU>
addpath(confidenceFolder,orbitFolder,stageFolder,fuxianFolder);

suite = stage55ProjectTestSuite( ...
    StageFolder=stageFolder, ...
    ComparisonFolder=fuxianFolder, ...
    IncludeFuxianduibi=options.IncludeFuxianduibi);
runner = matlab.unittest.TestRunner.withTextOutput;
results = runner.run(suite);

failedCount = sum([results.Failed]);
incompleteCount = sum([results.Incomplete]);
fprintf(['STAGE55_TEST_SUMMARY total=%d passed=%d failed=%d ' ...
    'incomplete=%d\n'],numel(results),sum([results.Passed]), ...
    failedCount,incompleteCount);
if failedCount > 0 || incompleteCount > 0
    error('SatelliteFig3:Stage55TestsFailed', ...
        'One or more canonical Stage55 tests failed or were incomplete.');
end
end
