classdef test_stage15_two_scenario_ber_wiring < SenLoRaStageTestCase
    %TEST_STAGE15_TWO_SCENARIO_BER_WIRING MATLAB unit-test wrapper for this stage regression.

    methods (Test)
        function runRegression(~)
            check_test_stage15_two_scenario_ber_wiring();
        end
    end
end

function check_test_stage15_two_scenario_ber_wiring()
%TEST_STAGE15_TWO_SCENARIO_BER_WIRING Verify shared data/noise and outputs.

snrDb = -16;
report = run_stage15_two_scenario_ber_smoke( ...
    SnrGridDb=snrDb,FrameCount=1, ...
    SymbolSeedBase=2026081900,NoiseSeedBase=2026082000, ...
    OutputFolderName='stage15_two_scenario_ber_wiring_test');
tableOut = report.table;

assert(height(tableOut) == 2, ...
    'One SNR point must produce one row for each orbit scenario.');
assert(all(tableOut.bits == 704), ...
    'Each smoke-test frame must contain 704 decoded payload bits.');
assert(tableOut.errAwgn(1) == tableOut.errAwgn(2), ...
    'The two scenarios did not reuse the same AWGN payload/noise sample.');
assert(report.commonNoiseMaxDifference < 1e-12, ...
    'The two orbit scenarios did not receive identical noise samples.');
assert(all(tableOut.hardAccepted <= 112) && ...
        all(tableOut.senAccepted <= 112), ...
    'A receiver accepted more pilots than the payload contains.');
assert(isfile(fullfile(report.resultDir,'two_scenario_ber_smoke.csv')) && ...
        isfile(report.imagePath), ...
    'The BER smoke runner did not save its required outputs.');

fprintf('Stage 15 two-scenario BER wiring test passed.\n');
end
