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
            testCase.verifyEqual(cfg.radio.sf,12);
            testCase.verifyEqual(cfg.radio.bandwidthHz,125e3);
            testCase.verifyEqual(cfg.channel.ricianKDb,10);
            testCase.verifyEqual(cfg.orbit.case1StartTimeSec,-366);
            testCase.verifyEqual(cfg.orbit.case2StartTimeSec,0);
            testCase.verifyFalse(cfg.provenance.fittedOrTuned);
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
