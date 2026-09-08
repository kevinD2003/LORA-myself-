function results=runV4R6MechanismTests()
v4SetupPaths();suite=[matlab.unittest.TestSuite.fromClass(?V4R6TwoDownchirpRateTest) matlab.unittest.TestSuite.fromClass(?V4PaperNativeEstimatorIsolationTest) matlab.unittest.TestSuite.fromClass(?V4TrackAScheduleTest)];results=run(suite);if ~all([results.Passed]),error('V4:R6Mechanism','R6 mechanism tests failed.');end
end
