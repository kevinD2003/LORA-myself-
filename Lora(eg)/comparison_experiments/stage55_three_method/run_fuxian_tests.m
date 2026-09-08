%RUN_FUXIAN_TESTS Execute and save all class-based comparison tests.

comparisonRoot = fileparts(mfilename('fullpath'));
sourceRoot = fuxianSourceRoot(comparisonRoot);
savedPath = path;
restorePath = onCleanup(@() path(savedPath));
addpath(sourceRoot,'-begin');
addpath(comparisonRoot,'-begin');

import matlab.unittest.TestRunner
import matlab.unittest.TestSuite
suite = TestSuite.fromFolder(fullfile(comparisonRoot,'tests'));
runner = TestRunner.withTextOutput('OutputDetail',3);
results = runner.run(suite);
testTable = table(string({results.Name}).', ...
    [results.Passed].',[results.Failed].', ...
    [results.Incomplete].',[results.Duration].', ...
    'VariableNames',{'Name','Passed','Failed','Incomplete','DurationS'});
writetable(testTable,fullfile(comparisonRoot,'results', ...
    'unit_test_results.csv'));
if any([results.Failed]) || any([results.Incomplete])
    error('FuxianDuibi:TestFailure', ...
        'At least one fuxianduibi test did not pass.');
end
fprintf('Fuxian tests passed: %d/%d\n', ...
    nnz([results.Passed]),numel(results));
