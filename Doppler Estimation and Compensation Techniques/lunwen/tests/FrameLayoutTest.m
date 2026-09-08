classdef FrameLayoutTest < matlab.unittest.TestCase
    methods (TestClassSetup)
        function addProjectPaths(testCase)
            import matlab.unittest.fixtures.PathFixture
            projectRoot = fileparts(fileparts(mfilename('fullpath')));
            testCase.applyFixture(PathFixture(fullfile(projectRoot, 'src')));
            testCase.applyFixture(PathFixture(fullfile(projectRoot, 'config')));
        end
    end

    methods (Test)
        function testLdroAlphabet(testCase)
            cfg = paperSf12Config();
            testCase.verifyTrue(cfg.radio.ldro);
            testCase.verifyEqual(cfg.radio.dataAlphabetSize, 1024);
            testCase.verifyEqual(cfg.radio.dataBinSpacing, 4);
        end

        function testPayloadAndMidambleCounts(testCase)
            cfg = paperSf12Config();
            layout = buildFrameLayout(cfg);
            testCase.verifyEqual(layout.payloadSymbols, 23);
            testCase.verifyEqual(layout.numberOfMidambles, 8);
            testCase.verifyEqual(numel(layout.slotKind), 31);
        end

        function testMidambleLocations(testCase)
            cfg = paperSf12Config();
            layout = buildFrameLayout(cfg);
            locations = find(layout.slotKind == "midamble");
            testCase.verifyEqual(locations, [4 8 12 16 20 24 28 31]);
        end

        function testPointToaRoundsToPaperValue(testCase)
            cfg = paperSf12Config();
            layout = buildFrameLayout(cfg);
            testCase.verifyEqual(layout.pointToaS, ...
                1.089536, 'AbsTol', 1e-12);
            testCase.verifyEqual(round(layout.pointToaS, 3), ...
                cfg.paper.pointToaSf12S, 'AbsTol', 1e-12);
        end

        function testTableThreeUsesFractionalMidambleCount(testCase)
            analysis = analyzePublicationConsistency(paperSf12Config());
            testCase.verifyEqual(analysis.fractionalMidambleCount, ...
                23/3, 'AbsTol', 1e-12);
            testCase.verifyEqual(analysis.floorRealizableToaS, ...
                1.318912, 'AbsTol', 1e-12);
            testCase.verifyEqual(analysis.ceilingRealizableToaS, ...
                1.351680, 'AbsTol', 1e-12);
            testCase.verifyEqual(round( ...
                analysis.fractionalApproximationToaS, 3), ...
                1.341, 'AbsTol', 1e-12);
            testCase.verifyTrue(analysis.paperInternalConflictProved);
        end
    end
end
