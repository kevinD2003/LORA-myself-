classdef V4SourceFreezeTest < matlab.unittest.TestCase
    methods (Test)
        function canonicalAndSnapshotHashesMatch(testCase)
            root = v4SetupPaths();
            result = v4VerifyReadOnlySources(root);
            testCase.verifyEqual(result.fileCount,34);
            testCase.verifyTrue(result.passed);
        end
        function frozenSourceIsNotOnActivePath(testCase)
            root = v4SetupPaths();
            entries = string(strsplit(path,pathsep));
            frozen = string(fullfile(root,'src','upstream_sf11'));
            testCase.verifyFalse(any(strcmpi(entries,frozen)));
        end
        function normativeIdentitiesMatch(testCase)
            root = v4SetupPaths();
            plan = jsondecode(fileread(fullfile(root,'config','plan_manifest.json')));
            testCase.verifyEqual(plan.planVersion,'V4-noLDRO-plan-R3-project-aligned');
            testCase.verifyEqual(plan.planSha256, ...
                '3c1485bd80539235eefa6f1d906f289357b10467a3055d490f023f5409cfd94e');
            testCase.verifyEqual(plan.alignmentSha256, ...
                'aae620c84c3f037273a8fae8f53993c4fee846d536f9c1e183e568800cad49cb');
        end
    end
end
