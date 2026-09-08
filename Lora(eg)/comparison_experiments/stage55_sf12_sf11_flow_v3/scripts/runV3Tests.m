function results = runV3Tests()
%RUNV3TESTS Run the currently implemented V3 regression gates.

root = v3SetupPaths();
suite = matlab.unittest.TestSuite.fromFolder(fullfile(root,'tests'), ...
    'IncludingSubfolders',true);
results = run(suite);
disp(table(results));
if ~all([results.Passed])
    error('V3:TestFailure','At least one V3 regression test failed.');
end
end
