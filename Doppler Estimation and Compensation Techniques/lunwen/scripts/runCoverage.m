%RUNCOVERAGE Run tests and publish R2022a statement/function coverage.

projectRoot = fileparts(fileparts(mfilename('fullpath')));
sourceFolder = fullfile(projectRoot, 'src');
testFolder = fullfile(projectRoot, 'tests');
resultsFolder = fullfile(projectRoot, 'results');
reportFolder = fullfile(resultsFolder, 'coverage_report');
addpath(sourceFolder);
addpath(fullfile(projectRoot, 'config'));

% CoverageReport in R2022a exposes its aggregate metrics through the report's
% generated OverallCoverageData.js file. Recreate only this exact artifact.
assert(startsWith(reportFolder, [resultsFolder filesep]));
if isfolder(reportFolder)
    rmdir(reportFolder, 's');
end

import matlab.unittest.TestRunner
import matlab.unittest.TestSuite
import matlab.unittest.plugins.CodeCoveragePlugin
import matlab.unittest.plugins.codecoverage.CoverageReport

suite = TestSuite.fromFolder(testFolder);
runner = TestRunner.withTextOutput;
coverageFormat = CoverageReport(reportFolder);
plugin = CodeCoveragePlugin.forFolder(sourceFolder, ...
    'Producing', coverageFormat);
runner.addPlugin(plugin);
testResults = runner.run(suite);
assert(all([testResults.Passed]) && ~any([testResults.Failed]) && ...
    ~any([testResults.Incomplete]));

dataPath = fullfile(reportFolder, 'release', 'coverageData', ...
    'OverallCoverageData.js');
rawData = fileread(dataPath);
jsonStart = find(rawData == '{', 1, 'first');
jsonEnd = find(rawData == '}', 1, 'last');
assert(~isempty(jsonStart) && ~isempty(jsonEnd) && jsonEnd > jsonStart);
coverageData = jsondecode(rawData(jsonStart:jsonEnd));
metrics = coverageData.OverallCoverageMetrics;

summary = struct();
summary.matlabRelease = version('-release');
summary.testCount = numel(testResults);
summary.sourceFileCount = coverageData.TotalFiles;
summary.statementExecuted = metrics.Statement.Executed;
summary.statementTotal = metrics.Statement.Total;
summary.statementCoveragePercent = ...
    metrics.Statement.PercentCoverage;
summary.functionExecuted = metrics.Function.Executed;
summary.functionTotal = metrics.Function.Total;
summary.functionCoveragePercent = metrics.Function.PercentCoverage;
summary.minimumStatementCoveragePercent = 90;
summary.minimumFunctionCoveragePercent = 95;
if summary.statementCoveragePercent >= ...
        summary.minimumStatementCoveragePercent && ...
        summary.functionCoveragePercent >= ...
        summary.minimumFunctionCoveragePercent
    summary.state = "passed";
else
    summary.state = "failed";
end

summaryPath = fullfile(resultsFolder, 'coverage_summary.json');
fileId = fopen(summaryPath, 'w');
assert(fileId >= 0);
closeFile = onCleanup(@() fclose(fileId));
fprintf(fileId, '%s', jsonencode(summary));
assert(summary.state == "passed");
fprintf('Coverage summary written: %s\n', summaryPath);
