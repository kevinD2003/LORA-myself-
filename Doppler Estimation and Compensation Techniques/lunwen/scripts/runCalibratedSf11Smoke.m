%RUNCALIBRATEDSF11SMOKE 快速检查SF11校准接收机的机制排序。

projectRoot = fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(projectRoot, 'config'));
addpath(fullfile(projectRoot, 'src'));
cfg = calibratedPaperSf11Config();
limits = struct('batchPackets', 32, 'minimumPackets', 1000, ...
    'maximumPackets', 1000, 'minimumSymbolErrors', 0);
snrDb = max(cfg.monteCarlo.snrDb);

case1Point = simulateSerPoint(cfg, "case1", "point", snrDb, limits);
case1Midamble = simulateSerPoint( ...
    cfg, "case1", "midamble_point", snrDb, limits);
case2Point = simulateSerPoint(cfg, "case2", "point", snrDb, limits);
case2Midamble = simulateSerPoint( ...
    cfg, "case2", "midamble_point", snrDb, limits);

fprintf('SF11 Case1: Point=%g, Midamble=%g\n', ...
    case1Point.ser, case1Midamble.ser);
fprintf('SF11 Case2: Point=%g, Midamble=%g\n', ...
    case2Point.ser, case2Midamble.ser);
assert(case1Point.ser <= case1Midamble.ser, ...
    'SF11 Case1未满足Point不高于Midamble-Point。');
assert(case2Midamble.ser < case2Point.ser, ...
    'SF11 Case2未满足Midamble-Point优于Point。');
