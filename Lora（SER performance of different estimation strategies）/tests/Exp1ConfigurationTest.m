classdef Exp1ConfigurationTest < matlab.unittest.TestCase
    methods(Test)
        function frozenConfigurationAndParentHashes(testCase)
            exp1SetupPaths();
            config = exp1Config();
            report = exp1ValidateFrozenParent(config);
            testCase.verifyEqual(report.status,'PASS');
            testCase.verifyGreaterThanOrEqual(report.runtimeDependencyCount,43);
            manifest = jsondecode(fileread(config.parentManifestPath));
            lockedPaths = string({manifest.files.path});
            testCase.verifyTrue(any(lockedPaths == ...
                "src/stage55/v4RollingTrackerPass.m"));
            testCase.verifyEqual(config.parent.physicalSf,12);
            testCase.verifyEqual(config.parent.payloadSymbolCount,112);
            testCase.verifyEqual(config.parent.informationBitCount,768);
            testCase.verifyEqual(config.parent.commonTimelineSymbolCount,157);
            testCase.verifyEqual(config.parent.fftBinSpacingHz,30.517578125, ...
                'AbsTol',1e-12);
            implementation = exp1ImplementationDigest(config);
            testCase.verifyGreaterThan(implementation.fileCount,20);
        end

        function ablationReusesFormalPacketIdentity(testCase)
            exp1SetupPaths();
            config = exp1Config();
            formal = exp1SeedPlan(config,'formal',4,-24,17,'registered');
            ablation = exp1SeedPlan(config,'formal',4,-24,17,'registered');
            testCase.verifyEqual(ablation.payloadSeed,formal.payloadSeed);
            testCase.verifyEqual(ablation.noiseSeed,formal.noiseSeed);
            testCase.verifyEqual(ablation.channelSeed,formal.channelSeed);
            testCase.verifyEqual(ablation.ledgerHash,formal.ledgerHash);
        end
    end
end
