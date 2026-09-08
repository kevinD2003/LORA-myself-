function results = runSenLoRaProjectTests()
%RUNSENLORAPROJECTTESTS Discover and run the complete project test suite.

projectFolder = fileparts(mfilename("fullpath"));
projectContainer = fileparts(projectFolder);
orbitFolder = fullfile(projectContainer,"orbit_doppler");
stageFolder = fullfile(orbitFolder,"satellite_fig3_rolling8");

originalPath = path;
pathCleanup = onCleanup(@()path(originalPath));
addpath(projectFolder,orbitFolder,stageFolder);

stageSuite = stage55ProjectTestSuite(StageFolder=stageFolder);
suite = [ ...
    matlab.unittest.TestSuite.fromFile( ...
        fullfile(projectFolder,"testSenLoRaConfidence.m")), ...
    matlab.unittest.TestSuite.fromFile( ...
        fullfile(orbitFolder,"senloraBinomialBounds95Test.m")), ...
    stageSuite];

runner = matlab.unittest.TestRunner.withTextOutput;
results = runner.run(suite);
failedCount = sum([results.Failed]);
incompleteCount = sum([results.Incomplete]);
fprintf("PROJECT_TEST_SUMMARY total=%d passed=%d failed=%d incomplete=%d\n", ...
    numel(results),sum([results.Passed]),failedCount,incompleteCount);

if failedCount > 0 || incompleteCount > 0
    error("SenLoRa:ProjectTestsFailed", ...
        "One or more project tests failed or were incomplete.");
end
end
