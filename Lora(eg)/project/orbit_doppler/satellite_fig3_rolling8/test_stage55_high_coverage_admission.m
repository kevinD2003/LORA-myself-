classdef test_stage55_high_coverage_admission < SenLoRaStageTestCase
    %TEST_STAGE55_HIGH_COVERAGE_ADMISSION MATLAB unit-test wrapper for this regression.

    methods (Test)
        function runRegression(~)
            check_test_stage55_high_coverage_admission();
        end
    end
end

function check_test_stage55_high_coverage_admission()
%TEST_STAGE55_HIGH_COVERAGE_ADMISSION Require useful, reliable VP coverage.
%   Seeds are disjoint from the frozen Stage 52/53 formal experiments.

report = run_stage55_admission_root_cause_audit( ...
    SnrGridDb=-20,FramesPerRegion=8, ...
    OutputFolderName='stage55_high_coverage_test');
records = report.records;
accepted = sum(records.accepted);
falseAccepted = sum(records.falseAccepted);
releasedFrames = sum(records.rateReleased);
meanCfoRmse = mean(records.cfoRmseBins);

assert(accepted >= 48, ...
    'The revised receiver accepts fewer than three payload pilots per frame.');
assert(falseAccepted <= 1, ...
    'The higher-coverage policy admits too many wrong virtual pilots.');
assert(releasedFrames >= 10, ...
    'Fewer than 10/16 independent frames release payload rate tracking.');
assert(meanCfoRmse < 0.25, ...
    'The revised virtual-pilot coverage does not remove the CFO plateau.');
fprintf(['Stage 55 high-coverage admission test passed: %d pilots, ' ...
    '%d false, %d/16 released, %.4f-bin mean CFO RMSE.\n'], ...
    accepted,falseAccepted,releasedFrames,meanCfoRmse);
end
