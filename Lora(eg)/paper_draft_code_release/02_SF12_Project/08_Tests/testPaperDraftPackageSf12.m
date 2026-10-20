function tests = testPaperDraftPackageSf12()
%TESTPAPERDRAFTPACKAGESF12 Validate the published SF12 code package layout.
tests = functiontests(localfunctions);
end

function setupOnce(testCase)
testCase.TestData.originalPath = path;
root = fileparts(fileparts(mfilename('fullpath')));
addpath(root,fullfile(root,'05_Curve_Entry_Files'));
testCase.TestData.roots = paperDraftSetupSf12();
end

function teardownOnce(testCase)
path(testCase.TestData.originalPath);
end

function testConfigIsSf12(testCase)
c = testCase.TestData.roots.config.parent;
verifyEqual(testCase,c.physicalSf,12);
verifyEqual(testCase,c.samplesPerSymbol,4096);
verifyEqual(testCase,c.paperMidambleInterval,3);
verifyEqual(testCase,testCase.TestData.roots.ricianConfig.parent.physicalSf,12);
end

function testCurveFilesAreIndependent(testCase)
functions = {@curveSf12VpSymbolN8,@curveSf12HuangPrec, ...
    @curveSf12PaperMidamblePoint,@curveSf12IdealNative,@curveSf12IdealPaper, ...
    @curveSf12AwgnTheory,@curveSf12RicianTheoryReference};
specs = cellfun(@(entry)entry(),functions,'UniformOutput',false);
ids = cellfun(@(spec)spec.curveId,specs);
verifyEqual(testCase,numel(unique(ids)),7);
verifyTrue(testCase,all(cellfun(@(spec)spec.sf==12,specs)));
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
seeds=struct('payloadSeed',4100000201,'noiseSeed',4100000202, ...
    'channelSeed',4100000203,'paperExtraNoiseSeed',4100000204);
pair=acGeneratePair(config,-366,-21,"AWGN",seeds);
input=struct('pair',pair,'config',config);
outputs={curveSf12VpSymbolN8(input),curveSf12HuangPrec(input), ...
    curveSf12PaperMidamblePoint(input),curveSf12IdealNative(input), ...
    curveSf12IdealPaper(input)};
verifyTrue(testCase,all(cellfun(@(value) ...
    numel(value.detectedPhysicalBins)==112,outputs)));
theory=curveSf12AwgnTheory([-30;-29]);
verifySize(testCase,theory,[2 1]);
verifyTrue(testCase,all(isfinite(theory)&theory>=0&theory<=1));
verifyTrue(testCase,isfile(fullfile(testCase.TestData.roots.normalizedChannel, ...
    'theory','generate_full_grid.py')));
end

function testRicianEntryRejectsArbitraryPaths(testCase)
caught=false;
try
    curveSf12RicianTheoryReference("unsafe-output-path");
catch
    caught=true;
end
verifyTrue(testCase,caught);
end

function testCrossSfMetadataIsolation(testCase)
sf12Root=testCase.TestData.roots.root;
releaseRoot=fileparts(sf12Root);
sf7Root=fullfile(releaseRoot,'01_SF7_Project');
addpath(sf7Root,fullfile(sf7Root,'05_Curve_Entry_Files'));
paperDraftSetupSf7();
sf7Before=curveSf7VpSymbolN8();
paperDraftSetupSf12();
sf12=curveSf12VpSymbolN8();
sf7After=curveSf7VpSymbolN8();
verifyEqual(testCase,[sf7Before.sf sf12.sf sf7After.sf],[7 12 7]);
verifyEqual(testCase,which('paperDraftCurveSpecSf7'), ...
    fullfile(sf7Root,'05_Curve_Entry_Files','paperDraftCurveSpecSf7.m'));
verifyEqual(testCase,which('paperDraftCurveSpecSf12'), ...
    fullfile(sf12Root,'05_Curve_Entry_Files','paperDraftCurveSpecSf12.m'));
end

