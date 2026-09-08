classdef V4Stage3SManifestTest < matlab.unittest.TestCase
    methods (Test)
        function r5IdentityAndAuthorization(testCase)
            root=v4SetupPaths();m=jsondecode(fileread(fullfile(root,'config','plan_manifest_r5_stage3s.json')));
            testCase.verifyEqual(m.planSha256,v4Sha256(fullfile(root,'SF12无LDRO双轨完整实验V4方案_R5_STAGE3S.md')));
            testCase.verifyEqual(m.implementationAuthorization,'GRANTED_BY_USER_2026-09-08');
            testCase.verifyEqual(m.experimentBEntryRule,'REQUIRE_A_PASS');
        end
        function r3AndR4EvidenceUnchanged(testCase)
            root=v4SetupPaths();files={'r3_failure_evidence_manifest.json','r4_failure_evidence_manifest.json'};
            for f=1:2
                m=jsondecode(fileread(fullfile(root,'config',files{f})));
                for i=1:numel(m.files),testCase.verifyEqual(v4Sha256(fullfile(root,m.files(i).path)),m.files(i).sha256);end
            end
        end
        function newSeedsAndCandidatesAreIndependent(testCase)
            root=v4SetupPaths();s=jsondecode(fileread(fullfile(root,'config','seed_protocol_r5_stage3s.json')));
            values=struct2array(s.domains);testCase.verifyEqual(numel(unique(values)),numel(values));
            r4=jsondecode(fileread(fullfile(root,'config','seed_protocol_r4_stage3r.json')));
            testCase.verifyEmpty(intersect(values,struct2array(r4.domains)));
            for v=1:2
                t=jsondecode(fileread(fullfile(root,'config',sprintf('stage3s_candidate_table_v%02d.json',v))));
                names=fieldnames(t.fullFactorial);n=1;for k=1:numel(names),n=n*numel(t.fullFactorial.(names{k}));end
                testCase.verifyEqual(n,32);testCase.verifyEqual(t.calibrationPacketsPerCandidateCase,500);
            end
        end
    end
end
