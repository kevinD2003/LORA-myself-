function results=runV4Stage3RMechanismTests()
%RUNV4STAGE3RMECHANISMTESTS New tests plus inherited Track A regressions.
v4SetupPaths();
classes={?V4Stage3RMechanismTest,?V4TrackAScheduleTest, ...
    ?V4PaperAnchorDiagnosticTest,?V4TrackACausalityTest,?V4TrackARandomPairingTest};
suite=matlab.unittest.TestSuite.fromClass(classes{1});
for index=2:numel(classes),suite=[suite matlab.unittest.TestSuite.fromClass(classes{index})];end %#ok<AGROW>
results=run(suite);
if ~all([results.Passed]),error('V4:Stage3RMechanism','Stage 3R mechanism tests failed.');end
end
