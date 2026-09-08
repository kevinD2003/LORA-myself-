function results = runV4Tests()
%RUNV4TESTS Run the currently implemented V4 regression gates.

root = v4SetupPaths();
suite = matlab.unittest.TestSuite.fromFolder(fullfile(root,'tests'), ...
    'IncludingSubfolders',true);
results = run(suite);
disp(table(results));
if ~all([results.Passed])
    error('V4:TestFailure','At least one V4 regression test failed.');
end
end
