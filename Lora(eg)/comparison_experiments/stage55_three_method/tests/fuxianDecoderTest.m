classdef fuxianDecoderTest < matlab.unittest.TestCase
    methods (TestClassSetup)
        function addProjectPaths(testCase)
            import matlab.unittest.fixtures.PathFixture
            comparisonRoot = fileparts(fileparts(mfilename('fullpath')));
            sourceRoot = fuxianSourceRoot(comparisonRoot);
            testCase.applyFixture(PathFixture(sourceRoot));
            testCase.applyFixture(PathFixture(comparisonRoot));
        end
    end

    methods (Test)
        function testNoiselessDeliveredBits(testCase)
            fixture = localNoiselessFixture();
            testCase.verifyEqual( ...
                fixture.huang.decodedDataBits,fixture.payload.dataBits);
            testCase.verifyEqual( ...
                fixture.senlora.decodedDataBits,fixture.payload.dataBits);
            testCase.verifyEqual( ...
                fixture.paper.decodedDataBits,fixture.payload.dataBits);
            testCase.verifyEqual( ...
                fixture.paperV2.decodedDataBits,fixture.payload.dataBits);
        end

        function testNoiselessDataSymbols(testCase)
            fixture = localNoiselessFixture();
            reference = fixture.payload.symbolBins;
            testCase.verifyEqual( ...
                fixture.huang.detectedWaveformBins( ...
                fixture.layout.dataRows),reference);
            testCase.verifyEqual( ...
                fixture.senlora.detectedWaveformBins( ...
                fixture.layout.dataRows),reference);
            testCase.verifyEqual( ...
                fixture.paper.detectedWaveformBins( ...
                fixture.layout.dataRows),reference);
            testCase.verifyEqual( ...
                fixture.paperV2.detectedWaveformBins( ...
                fixture.layout.dataRows),reference);
        end

        function testOnlyPaperUsesExplicitMidambles(testCase)
            fixture = localNoiselessFixture();
            testCase.verifyFalse(any(fixture.huang.tracker.pilotAccepted( ...
                fixture.layout.midambleRows)));
            testCase.verifyFalse(any(fixture.senlora.pilotAccepted( ...
                fixture.layout.midambleRows)));
            testCase.verifyTrue(all( ...
                fixture.paper.explicitMidambleAccepted));
            testCase.verifyEqual( ...
                fixture.paper.explicitMidambleRows,[57;106]);
            testCase.verifyTrue(all( ...
                fixture.paperV2.explicitMidambleAccepted));
        end

        function testV2MidambleUpdateIsCausallyDelayed(testCase)
            fixture = localNoiselessFixture();
            testCase.verifyEqual( ...
                fixture.paperV2.explicitMidambleAppliedAtRows,[59;108]);
            testCase.verifyEqual( ...
                fixture.paperV2.tracker.pilotAppliedAtRows( ...
                fixture.layout.midambleRows),[59;108]);
        end

        function testKnownMidambleQualityBranchUsesOnlyTrackingPilot(testCase)
            experiment = fuxianComparisonConfig( ...
                MidambleSpacingMode="visible_rate_matched", ...
                IncludeTerminalMidamble=true);
            config = experiment.physicalConfig;
            payload = satelliteFig3GeneratePayload(config,2026751801);
            layout = fuxianMidambleLayout(payload.symbolBins,experiment);
            [rx,~,~] = generateContinuousSatelliteFrame( ...
                layout.physicalBins,config,StartTimeSec=-300, ...
                SampleSnrDb=Inf,NoiseSeed=2026751901, ...
                InitialPhaseRad=0,NextSymbolBin=0);
            decoded = fuxianKnownMidambleQualityDecode( ...
                rx,config,layout);
            testCase.verifyEqual(decoded.decodedDataBits,payload.dataBits);
            testCase.verifyTrue(all(decoded.explicitMidambleAccepted));
            testCase.verifyEqual(numel(decoded.explicitMidambleAccepted),1);
            testCase.verifyFalse(decoded.tracker.pilotAccepted( ...
                layout.terminalMidambleRows));
            testCase.verifyFalse(decoded.usesPayloadFeedback);
        end

        function testNoReceiverUsesOrbitTruth(testCase)
            fixture = localNoiselessFixture();
            testCase.verifyFalse(fixture.huang.usesOrbitPrior);
            testCase.verifyFalse(fixture.senlora.usesOrbitPrior);
            testCase.verifyFalse(fixture.paper.usesOrbitPrior);
            testCase.verifyFalse(fixture.paperV2.usesOrbitPrior);
        end
    end
end

function fixture = localNoiselessFixture()
experiment = fuxianComparisonConfig();
config = experiment.physicalConfig;
payload = satelliteFig3GeneratePayload(config,2026551801);
layout = fuxianMidambleLayout(payload.symbolBins,experiment);
[rx,~,~] = generateContinuousSatelliteFrame( ...
    layout.physicalBins,config,StartTimeSec=-300, ...
    SampleSnrDb=Inf,NoiseSeed=2026551901, ...
    InitialPhaseRad=0,NextSymbolBin=0);
fixture.payload = payload;
fixture.layout = layout;
fixture.huang = fuxianHuangDecode(rx,config,layout);
fixture.senlora = fuxianSenLoRaDecode(rx,config,layout);
fixture.paper = fuxianPaperMidamblePointDecode(rx,config,layout);
fixture.paperV2 = fuxianPaperMidamblePointDecodeV2(rx,config,layout);
end
