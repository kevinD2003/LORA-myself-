classdef (Abstract) SenLoRaStageTestCase < matlab.unittest.TestCase
    %SENLORASTAGETESTCASE Adds project folders for stage regression tests.

    methods (TestClassSetup)
        function addProjectFolders(testCase)
            stageFolder = fileparts(mfilename("fullpath"));
            orbitFolder = fileparts(stageFolder);
            projectFolder = fileparts(orbitFolder);

            testCase.applyFixture( ...
                matlab.unittest.fixtures.PathFixture(projectFolder));
            testCase.applyFixture( ...
                matlab.unittest.fixtures.PathFixture(orbitFolder));
            testCase.applyFixture( ...
                matlab.unittest.fixtures.PathFixture(stageFolder));
        end
    end
end
