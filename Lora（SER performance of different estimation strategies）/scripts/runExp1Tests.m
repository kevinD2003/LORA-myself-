function results = runExp1Tests()
%RUNEXP1TESTS Run the EXP1 MATLAB R2022a regression suite.

paths = exp1SetupPaths();
suite = matlab.unittest.TestSuite.fromFolder( ...
    fullfile(paths.projectRoot,'tests'),'IncludingSubfolders',true);
runner = matlab.unittest.TestRunner.withTextOutput();
results = runner.run(suite);
disp(table(results));
if any([results.Failed])
    error('EXP1:TestsFailed','One or more EXP1 tests failed.');
end
end
