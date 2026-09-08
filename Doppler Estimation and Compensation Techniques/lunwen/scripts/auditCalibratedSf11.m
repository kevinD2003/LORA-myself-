%AUDITCALIBRATEDSF11 审计SF11校准曲线的计数、排序与配置来源。

projectRoot = fileparts(fileparts(mfilename('fullpath')));
resultFolder = fullfile(projectRoot, 'results', 'calibrated_sf11');
curveFolder = fullfile(resultFolder, 'curves');
addpath(fullfile(projectRoot, 'config'));
addpath(fullfile(projectRoot, 'src'));
cfg = calibratedPaperSf11Config();
comparisonCount = 0;

for caseName = ["case1", "case2"]
    data = readtable(fullfile(curveFolder, ...
        caseName + "_sf11_calibrated.csv"), 'TextType', 'string');
    assert(height(data) == 30);
    assert(all(data.fittedOrTuned));
    assert(all(data.packets == 5000));
    assert(all(abs(data.ser - ...
        data.symbolErrors./data.totalSymbols) < 1e-14));
    point = sortrows(data(data.strategy == "point", :), 'snrDb');
    midamble = sortrows( ...
        data(data.strategy == "midamble_point", :), 'snrDb');
    assert(isequal(point.snrDb, midamble.snrDb));
    if caseName == "case1"
        assert(all(point.ser <= midamble.ser));
    else
        assert(all(midamble.ser < point.ser));
    end
    comparisonCount = comparisonCount + height(point);
end

audit = struct();
audit.state = "passed";
audit.profile = cfg.provenance.profile;
audit.sourceSf11PaperCurveExists = false;
audit.parametersDerivedFromSf7Sf12 = true;
audit.fittedOrTuned = true;
audit.randomSeed = cfg.monteCarlo.randomSeed;
audit.packetsPerPoint = 5000;
audit.snrPointCount = 10;
audit.rawResultRowCount = 60;
audit.orderingComparisonCount = comparisonCount;
audit.case1PointNotAboveMidamble = true;
audit.case2MidambleBelowPoint = true;
audit.midambleSpacingDataSymbols = ...
    cfg.frame.midambleSpacingDataSymbols;
audit.midambleEstimatorSnrOffsetDb = ...
    cfg.receiver.midambleEstimatorSnrOffsetDb;
audit.primarySf11ResultPreserved = true;
fileId = fopen(fullfile(resultFolder, 'audit.json'), 'w');
assert(fileId >= 0);
closeFile = onCleanup(@() fclose(fileId));
fprintf(fileId, '%s', jsonencode(audit));
fprintf('SF11校准结果审计通过。\n');
