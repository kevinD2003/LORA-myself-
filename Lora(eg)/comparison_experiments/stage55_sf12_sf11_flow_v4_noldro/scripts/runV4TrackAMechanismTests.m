function results = runV4TrackAMechanismTests()
root = v4SetupPaths(); %#ok<NASGU>
classes = {?V4TrackAScheduleTest,?V4PaperNativeEstimatorIsolationTest, ...
    ?V4PaperAnchorDiagnosticTest,?V4TrackACausalityTest,?V4TrackARandomPairingTest};
suite = matlab.unittest.TestSuite.fromClass(classes{1});
for index = 2:numel(classes)
    suite = [suite matlab.unittest.TestSuite.fromClass(classes{index})]; %#ok<AGROW>
end
results = run(suite);
if ~all([results.Passed]), error('V4:TrackAMechanism','Track A mechanism tests failed.'); end
end
