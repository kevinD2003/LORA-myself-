function results=runV4Stage3SMechanismTests()
v4SetupPaths();classes={?V4Stage3SMechanismTest,?V4TrackAScheduleTest, ...
    ?V4PaperNativeEstimatorIsolationTest,?V4PaperAnchorDiagnosticTest, ...
    ?V4TrackACausalityTest,?V4TrackARandomPairingTest};
suite=matlab.unittest.TestSuite.fromClass(classes{1});
for i=2:numel(classes),suite=[suite matlab.unittest.TestSuite.fromClass(classes{i})];end %#ok<AGROW>
results=run(suite);if ~all([results.Passed]),error('V4:Stage3SMechanism','Stage3S mechanism tests failed.');end
end
