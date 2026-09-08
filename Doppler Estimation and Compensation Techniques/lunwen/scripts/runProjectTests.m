function results = runProjectTests(testFolder)
%RUNPROJECTTESTS Execute project tests without relying on path-shadowable runtests.

arguments
    testFolder (1,1) string {mustBeFolder}
end

import matlab.unittest.TestRunner
import matlab.unittest.TestSuite

suite = TestSuite.fromFolder(testFolder);
runner = TestRunner.withTextOutput;
results = runner.run(suite);
end
