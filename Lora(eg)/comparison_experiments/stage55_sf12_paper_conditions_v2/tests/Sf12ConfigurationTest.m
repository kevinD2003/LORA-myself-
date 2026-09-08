classdef Sf12ConfigurationTest < matlab.unittest.TestCase
    methods (TestMethodSetup)
        function setup(testCase)
            root = fileparts(fileparts(mfilename('fullpath')));
            addpath(fullfile(root,'config'),fullfile(root,'src'));
            testCase.addTeardown(@()rmpath(fullfile(root,'config'), ...
                fullfile(root,'src')));
        end
    end
    methods (Test)
        function frozenPaperConditions(testCase)
            cfg = sf12PaperCommonConfig();
            testCase.verifyEqual(cfg.name, ...
                "stage55_sf12_paper_conditions_v2");
            testCase.verifyEqual(cfg.radio.sf,12);
            testCase.verifyEqual(cfg.radio.bandwidthHz,125e3);
            testCase.verifyEqual(cfg.channel.ricianKDb,10);
            testCase.verifyEqual(cfg.orbit.case1StartTimeSec,-366);
            testCase.verifyEqual(cfg.orbit.case2StartTimeSec,0);
            testCase.verifyFalse(cfg.provenance.fittedOrTuned);
        end
        function calibratedManifestIsSelfConsistent(testCase)
            cfg = sf12PaperCommonConfig();
            manifest = cfg.receiver.manifest;
            testCase.verifyEqual(manifest.schemaVersion,2);
            if manifest.calibrationRunCompleted
                testCase.verifyTrue(manifest.validationPassed);
                testCase.verifyEqual( ...
                    manifest.measurements.innovationLimitHz, ...
                    manifest.parameters.innovationLimitHz,'AbsTol',1e-12);
                testCase.verifyTrue(any(string( ...
                    manifest.measurements.validationCases) == "case2"));
            end
        end
        function checkpointComparisonIgnoresOnlyMetadata(testCase)
            original = sf12PaperCommonConfig();
            metadataChanged = original;
            metadataChanged.receiver.manifest.calibrationTimestamp = ...
                '2099-01-01 00:00:00';
            testCase.verifyEqual(sf12EffectiveConfig(original), ...
                sf12EffectiveConfig(metadataChanged));
            parameterChanged = metadataChanged;
            parameterChanged.receiver.innovationLimitHz = ...
                original.receiver.innovationLimitHz+1;
            testCase.verifyNotEqual(sf12EffectiveConfig(original), ...
                sf12EffectiveConfig(parameterChanged));
        end
        function exactMidambleLayout(testCase)
            layout = sf12BuildFrameLayout(sf12PaperCommonConfig());
            testCase.verifyEqual(layout.midambleAfterDataIndex,[3:3:21,23].');
            testCase.verifyEqual(numel(layout.dataRows),23);
            testCase.verifyEqual(numel(layout.midambleRows),8);
            testCase.verifyEqual(numel(layout.trackingMidambleRows),7);
            testCase.verifyEqual(layout.terminalMidambleRow,31);
        end
        function disjointSeedDomains(testCase)
            cfg = sf12PaperCommonConfig();
            a = sf12RandomSeeds(cfg,"calibration","case1",1,1);
            b = sf12RandomSeeds(cfg,"validation","case1",1,1);
            c = sf12RandomSeeds(cfg,"formal","case1",1,1);
            testCase.verifyEqual(numel(unique([a.payloadSeed,b.payloadSeed, ...
                c.payloadSeed])),3);
            testCase.verifyEqual(a.noiseSeed,a.channelSeed);
        end
    end
end
