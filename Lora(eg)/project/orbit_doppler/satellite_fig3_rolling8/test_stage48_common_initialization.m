classdef test_stage48_common_initialization < SenLoRaStageTestCase
    %TEST_STAGE48_COMMON_INITIALIZATION MATLAB unit-test wrapper for this regression.

    methods (Test)
        function runRegression(~)
            check_test_stage48_common_initialization();
        end
    end
end

function check_test_stage48_common_initialization()
%TEST_STAGE48_COMMON_INITIALIZATION Fair static-PREC/SenLoRa start state.

config = satelliteFig3Config();
[window,~] = satelliteFig3VisibilityWindow(config);
known = zeros(config.bootstrapPilotCount,1);
payload = satelliteFig3GeneratePayload(config,2026120101);
labels = [known;payload.symbolBins];
payloadRows = config.bootstrapPilotCount+1:config.frameSymbolCount;
sceneStartSec = [-window.deltaTimeOutSec,window.deltaTimeInSec];

assert(nargin('satelliteFig3HuangPrecStaticCpDecode') == 3, ...
    'The static literature baseline must not accept channel truth.');
assert(nargin('satelliteFig3SenLoRaVirtualPilotDecode') == 3, ...
    'The SenLoRa comparison receiver must not accept channel truth.');

for scene = 1:numel(sceneStartSec)
    rx = generateContinuousSatelliteFrame(labels,config, ...
        StartTimeSec=sceneStartSec(scene),SampleSnrDb=Inf);
    staticPrec = satelliteFig3HuangPrecStaticCpDecode(rx,config,known);
    senlora = satelliteFig3SenLoRaVirtualPilotDecode(rx,config,known);
    firstSenPass = senlora.iterationHistory(1).tracker;

    assert(isequaln(staticPrec.tracker.bootstrap,firstSenPass.bootstrap), ...
        'The two methods did not receive an identical bootstrap estimate.');
    assert(staticPrec.bootstrap.epsilonHatBins == ...
        senlora.commonBootstrap.epsilonHatBins, ...
        'The two methods did not share Huang''s CFO estimate.');
    assert(staticPrec.tracker.predictedPhaseStartRad(payloadRows(1)) == ...
        firstSenPass.predictedPhaseStartRad(payloadRows(1)), ...
        'The two methods did not share the first-payload start phase.');
    assert(~any(staticPrec.tracker.pilotAccepted(payloadRows)), ...
        'Static PREC accepted a payload virtual pilot.');
    assert(max(abs(diff( ...
        staticPrec.tracker.predictedCfoBins(payloadRows)))) < 1e-12, ...
        'Static PREC did not freeze its payload CFO.');
    assert(max(abs( ...
        staticPrec.tracker.predictedRateBinsPerSec(payloadRows))) < 1e-12, ...
        'Static PREC used a nonzero Doppler-rate estimate.');
    assert(~staticPrec.usesPayloadFeedback && ~staticPrec.usesDopplerRate, ...
        'Static PREC metadata contradicts its required algorithm boundary.');
    assert(~senlora.usesOrbitPrior && ...
        isfinite(senlora.initialRateBinsPerSec), ...
        'SenLoRa comparison path used an orbit rate prior.');

    truePayloadCfoBins = truthCfoBins(labels,config,sceneStartSec(scene));
    staticError = staticPrec.tracker.predictedCfoBins(payloadRows)- ...
        truePayloadCfoBins(payloadRows);
    senError = senlora.tracker.predictedCfoBins(payloadRows)- ...
        truePayloadCfoBins(payloadRows);
    if scene == 2
        assert(sum(senlora.pilotAccepted(payloadRows)) >= 2, ...
            'Noise-free high-rate SenLoRa did not start virtual-pilot tracking.');
        assert(sqrt(mean(senError.^2)) < 0.05 && ...
                sqrt(mean(staticError.^2)) > 0.5, ...
            'The noise-free mechanism check did not isolate rate tracking.');
    end

    % Changing every payload sample must not alter the static compensation
    % state, even though it is allowed to alter the decoded payload bits.
    rxAltered = rx;
    rxAltered(payloadRows,:) = rxAltered(payloadRows,end:-1:1);
    staticAltered = satelliteFig3HuangPrecStaticCpDecode( ...
        rxAltered,config,known);
    assert(isequaln(staticPrec.tracker.bootstrap, ...
        staticAltered.tracker.bootstrap), ...
        'Static bootstrap leaked information from payload samples.');
    assert(isequaln(staticPrec.tracker.predictedCfoBins, ...
        staticAltered.tracker.predictedCfoBins), ...
        'Static compensation state depended on payload samples.');
end

fprintf('Stage 48 common-initialization fairness test passed.\n');
end

function cfoBins = truthCfoBins(labels,config,startTimeSec)
[~,~,truth] = generateContinuousSatelliteFrame(labels,config, ...
    StartTimeSec=startTimeSec,SampleSnrDb=Inf);
cfoBins = truth.trueDopplerHz/config.fftBinSpacingHz;
end
