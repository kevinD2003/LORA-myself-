function results = runSf12Tests()
%RUNSF12TESTS Run all isolated SF12 comparison tests.

root = sf12SetupPaths();
suite = matlab.unittest.TestSuite.fromFolder(fullfile(root,'tests'));
results = run(suite);
assert(~any([results.Failed]) && ~any([results.Incomplete]), ...
    'SF12 comparison tests failed or were incomplete.');
end
