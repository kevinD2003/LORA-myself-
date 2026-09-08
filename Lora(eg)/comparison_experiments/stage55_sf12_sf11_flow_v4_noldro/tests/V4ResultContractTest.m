classdef V4ResultContractTest < matlab.unittest.TestCase
    methods (Test)
        function requiredContractsAreFrozen(testCase)
            root = v4SetupPaths();
            contract = jsondecode(fileread(fullfile(root,'config','result_contract.json')));
            testCase.verifyTrue(all(ismember({'algorithmSignature','seedLedgerHash'}, ...
                contract.commonIdentity)));
            testCase.verifyTrue(all(ismember({'vpUsedLabel','availableTimeSec', ...
                'appliedTimeSec'},contract.trackASymbol)));
            testCase.verifyTrue(all(ismember({'geometryErasure','mlBitCount'}, ...
                contract.trackBFrame)));
            testCase.verifyTrue(all(ismember({'goodputBps','systemPerMl'}, ...
                contract.trackBPass)));
        end
        function manifestSignatureIsStable(testCase)
            root = v4SetupPaths();
            a = v4BuildRunManifest(root,struct('trackId','contract-test'));
            b = v4BuildRunManifest(root,struct('trackId','contract-test'));
            testCase.verifyEqual(a.algorithmSignature,b.algorithmSignature);
        end
    end
end
