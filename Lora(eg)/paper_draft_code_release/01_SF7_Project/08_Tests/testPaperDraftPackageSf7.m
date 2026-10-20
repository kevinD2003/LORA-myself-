function tests = testPaperDraftPackageSf7()
%TESTPAPERDRAFTPACKAGESF7 Validate the published SF7 code package layout.
tests = functiontests(localfunctions);
end

function setupOnce(testCase)
testCase.TestData.originalPath = path;
root = fileparts(fileparts(mfilename('fullpath')));
addpath(root,fullfile(root,'05_Curve_Entry_Files'));
testCase.TestData.roots = paperDraftSetupSf7();
end

function teardownOnce(testCase)
path(testCase.TestData.originalPath);
end

function testConfigIsSf7(testCase)
c = testCase.TestData.roots.config.parent;
verifyEqual(testCase,c.physicalSf,7);
verifyEqual(testCase,c.samplesPerSymbol,128);
verifyEqual(testCase,c.paperMidambleInterval,12);
verifyEqual(testCase,testCase.TestData.roots.ricianConfig.parent.physicalSf,7);
end

function testCurveFilesAreIndependent(testCase)
functions = {@curveSf7VpSymbolN8,@curveSf7HuangPrec, ...
    @curveSf7PaperMidamblePoint,@curveSf7IdealNative,@curveSf7IdealPaper, ...
    @curveSf7AwgnTheory,@curveSf7RicianTheoryReference};
specs = cellfun(@(entry)entry(),functions,'UniformOutput',false);
ids = cellfun(@(spec)spec.curveId,specs);
verifyEqual(testCase,numel(unique(ids)),7);
verifyTrue(testCase,all(cellfun(@(spec)spec.sf==7,specs)));
end

function testOnlyCompletedFiguresArePublished(testCase)
root = testCase.TestData.roots.root;
awgn = dir(fullfile(root,'12_Result_Figures','01_AWGN_1000_Packets','*.png'));
theory = dir(fullfile(root,'12_Result_Figures','02_Rician_Theory_1000_Packets','*.png'));
comparison = dir(fullfile(root,'12_Result_Figures','03_Rician_Comparison_RUNNING','*.png'));
verifyEqual(testCase,numel(awgn),6);
verifyEqual(testCase,numel(theory),3);
verifyEmpty(testCase,comparison);
end

function testCurveEntriesExecute(testCase)
config=testCase.TestData.roots.awgnConfig;
seeds=struct('payloadSeed',4100000101,'noiseSeed',4100000102, ...
    'channelSeed',4100000103,'paperExtraNoiseSeed',4100000104);
pair=acGeneratePair(config,-366,-6,"AWGN",seeds);
input=struct('pair',pair,'config',config);
outputs={curveSf7VpSymbolN8(input),curveSf7HuangPrec(input), ...
    curveSf7PaperMidamblePoint(input),curveSf7IdealNative(input), ...
    curveSf7IdealPaper(input)};
verifyTrue(testCase,all(cellfun(@(value) ...
    numel(value.detectedPhysicalBins)==112,outputs)));
theory=curveSf7AwgnTheory([-15;-14]);
verifySize(testCase,theory,[2 1]);
verifyTrue(testCase,all(isfinite(theory)&theory>=0&theory<=1));
verifyTrue(testCase,isfile(fullfile(testCase.TestData.roots.normalizedChannel, ...
    'theory','generate_full_grid.py')));
end

function testRicianEntryRejectsArbitraryPaths(testCase)
caught=false;
try
    curveSf7RicianTheoryReference("unsafe-output-path");
catch
    caught=true;
end
verifyTrue(testCase,caught);
end

