function results = run_all_tests()
%RUN_ALL_TESTS Execute paper-anchor and V4-bridge regression tests.

root = dreSetupPaths(true);
suite = testsuite(fullfile(root,'tests'),'IncludeSubfolders',true);
results = run(suite);
disp(table(results));
if any([results.Failed])
    error('DRE:TestsFailed','One or more reproduction tests failed.');
end
end

