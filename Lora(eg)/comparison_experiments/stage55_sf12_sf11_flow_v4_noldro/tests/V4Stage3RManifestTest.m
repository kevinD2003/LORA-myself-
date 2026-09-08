classdef V4Stage3RManifestTest < matlab.unittest.TestCase
    methods (Test)
        function planAndAuthorizationAreFrozen(testCase)
            root=v4SetupPaths();
            manifest=jsondecode(fileread(fullfile(root,'config','plan_manifest_r4_stage3r.json')));
            testCase.verifyEqual(manifest.planVersion,'V4-noLDRO-plan-R4-track-a-stage3r');
            testCase.verifyEqual(manifest.planSha256,v4Sha256(fullfile(root,'SF12无LDRO双轨完整实验V4方案.md')));
            testCase.verifyEqual(manifest.implementationAuthorization,'GRANTED_BY_USER_2026-09-07');
            testCase.verifyEqual(manifest.experimentBEntryRule,'REQUIRE_A_PASS');
        end
        function oldFailureEvidenceIsUnchanged(testCase)
            root=v4SetupPaths();
            manifest=jsondecode(fileread(fullfile(root,'config','r3_failure_evidence_manifest.json')));
            for index=1:numel(manifest.files)
                item=manifest.files(index);
                testCase.verifyEqual(v4Sha256(fullfile(root,item.path)),item.sha256);
            end
            testCase.verifyFalse(manifest.allowOverwrite);
            testCase.verifyFalse(manifest.allowMergeWithR4);
        end
        function seedDomainsAndCandidateBudgetsAreFrozen(testCase)
            root=v4SetupPaths();
            seed=jsondecode(fileread(fullfile(root,'config','seed_protocol_r4_stage3r.json')));
            values=struct2array(seed.domains);
            testCase.verifyEqual(numel(unique(values)),numel(values));
            old=jsondecode(fileread(fullfile(root,'config','seed_protocol.json')));
            testCase.verifyEmpty(intersect(values,struct2array(old.roots)));
            for version=1:2
                table=jsondecode(fileread(fullfile(root,'config',sprintf('stage3r_candidate_table_v%02d.json',version))));
                names=fieldnames(table.fullFactorial); count=1;
                for field=1:numel(names),count=count*numel(table.fullFactorial.(names{field}));end
                testCase.verifyEqual(count,32);
                testCase.verifyEqual(table.calibrationPacketsPerCandidateCase,500);
            end
        end
    end
end
