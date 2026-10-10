classdef SenloraSymmetricV8ModelTest < matlab.unittest.TestCase
    methods (Test)
        function endpointsBlendCompleteTrajectories(testCase)
            c = struct('bootstrapPilotCount',8,'symbolDurationSec',0.1);
            common = localStaticBootstrap(c);
            joint = struct( ...
                'cfoAtFirstPreambleStartBins',-0.4, ...
                'rateBinsPerSec',2.0, ...
                'phaseAtFirstPreambleStartRad',-0.7);

            static = senloraSymmetricV8BlendBootstrap(common,joint,0,c);
            dynamic = senloraSymmetricV8BlendBootstrap(common,joint,1,c);
            middle = senloraSymmetricV8BlendBootstrap(common,joint,0.35,c);

            testCase.verifyEqual(static.phaseModelCycles, ...
                static.staticPhaseModelCycles,'AbsTol',1e-12);
            testCase.verifyEqual(dynamic.phaseModelCycles, ...
                dynamic.alignedDynamicPhaseModelCycles,'AbsTol',1e-12);
            expected = static.staticPhaseModelCycles+0.35*( ...
                dynamic.alignedDynamicPhaseModelCycles- ...
                static.staticPhaseModelCycles);
            testCase.verifyEqual(middle.phaseModelCycles,expected, ...
                'AbsTol',1e-12);
            testCase.verifyGreaterThan(abs( ...
                dynamic.dynamicCfoAtPayloadBins- ...
                dynamic.staticCfoAtPayloadBins),1e-6);
        end

        function payloadStartPhaseIsAlignedForEveryGain(testCase)
            c = struct('bootstrapPilotCount',8,'symbolDurationSec',0.1);
            common = localStaticBootstrap(c);
            joint = struct( ...
                'cfoAtFirstPreambleStartBins',0.7, ...
                'rateBinsPerSec',-1.5, ...
                'phaseAtFirstPreambleStartRad',1.1);
            [staticPhase,~] = v4BootstrapStateAtSymbol( ...
                common,c.bootstrapPilotCount,c);

            for gain = [0 0.2 0.5 0.9 1]
                bootstrap = senloraSymmetricV8BlendBootstrap( ...
                    common,joint,gain,c);
                [phase,~] = v4BootstrapStateAtSymbol( ...
                    bootstrap,c.bootstrapPilotCount,c);
                phaseError = angle(exp(1i*(phase-staticPhase)));
                testCase.verifyEqual(phaseError,0,'AbsTol',1e-12);
                testCase.verifyEqual(bootstrap.rateBinsPerSec, ...
                    gain*joint.rateBinsPerSec,'AbsTol',1e-12);
            end
        end

        function decodeDoesNotDisableVpAtStaticEndpoint(testCase)
            source = fileread(fullfile(fileparts(mfilename('fullpath')), ...
                'senloraSymmetricV8Decode.m'));
            testCase.verifyFalse(contains(source,'rateGain==0'));
            testCase.verifyTrue(contains(source, ...
                'senloraSymmetricV8JointBlockDecode'));
            testCase.verifyTrue(contains(source,'sameEntryAcrossCases'));
            testCase.verifyTrue(contains(source,'parametersFrozen'));
            testCase.verifyTrue(contains(source,'preambleRateBinsPerSec'));
            testCase.verifyTrue(contains(source,'candidateVirtualPilots'));
            testCase.verifyTrue(contains(source,'acceptedVirtualPilots'));
        end

        function mechanismPlanHasOnlyTheRegisteredGrid(testCase)
            parent = struct('bootstrapPilotCount',8, ...
                'payloadSymbolCount',112,'symbolDurationSec',0.032768);
            plan = senloraSymmetricV8Config(struct('parent',parent));
            testCase.verifyEqual(numel(plan.negativeOrbitStartSec),9);
            testCase.verifyEqual(plan.mechanismPacketsPerMirrorPair,20);
            testCase.verifyEqual(plan.maximumPasses,2);
            testCase.verifyEqual(plan.formalPacketsPerMirrorPair,1000);
            testCase.verifyTrue(plan.parametersFrozen);
            testCase.verifyEqual(plan.receiverVersion, ...
                'SenLoRa-V8-joint-block-frozen-v1');
            testCase.verifyFalse(plan.usesExplicitMidambles);
            testCase.verifyFalse(plan.usesOrbitTruthInReceiver);
            testCase.verifyFalse(plan.usesTargetSerInReceiver);
        end

        function mechanismArtifactsKeepZerosAndSignDependencies(testCase)
            source = fileread(fullfile(fileparts(mfilename('fullpath')), ...
                'runSenloraSymmetricV8Mechanism.m'));
            testCase.verifyFalse(contains(source,'semilogy('));
            testCase.verifyTrue(contains(source, ...
                'matlab.codetools.requiredFilesAndProducts'));
            testCase.verifyTrue(contains(source,'v4RollingTrackerPass'));
            testCase.verifyTrue(contains(source,'v4Stage55Confidence'));
            testCase.verifyTrue(contains(source,'v4DecodePayload'));
        end

        function reviewRunnerUsesIndependentFixedScope(testCase)
            root = fileparts(mfilename('fullpath'));
            source = fileread(fullfile(root, ...
                'runSenloraSymmetricV8JointBlockReview.m'));
            signatureSource = fileread(fullfile(root, ...
                'senloraSymmetricV8ReviewSignature.m'));
            testCase.verifyTrue(contains(source,'''review'''));
            testCase.verifyTrue(contains(source,'packetCount = 100'));
            testCase.verifyTrue(contains(source,'plan.reviewRootSeed'));
            testCase.verifyTrue(contains(signatureSource, ...
                'matlab.codetools.requiredFilesAndProducts'));
            testCase.verifyTrue(contains(signatureSource, ...
                'commonSearchStepBins'));
            testCase.verifyTrue(contains(signatureSource, ...
                'method_aligned_selected_parameters_v1.json'));
            testCase.verifyTrue(contains(signatureSource, ...
                'commonParameterSourceSha256'));
            testCase.verifyTrue(contains(source, ...
                'senloraSymmetricV8JointBlockDecode'));
            testCase.verifyTrue(contains(source,'senloraSymmetricV6Decode'));
            testCase.verifyTrue(contains(source,'exp1IdealDecode'));
            testCase.verifyFalse(contains(source,'''formal'''));
        end

        function reviewSerPlotUsesRequestedLogRange(testCase)
            source = fileread(fullfile(fileparts(mfilename('fullpath')), ...
                'plotSenloraSymmetricV8ReviewLogSer.m'));
            testCase.verifyTrue(contains(source,'semilogy('));
            testCase.verifyTrue(contains(source,'''YScale'',''log'''));
            testCase.verifyTrue(contains(source,'ylim([displayFloor displayCeiling])'));
            testCase.verifyTrue(contains(source,'xlim([-400 0])'));
            testCase.verifyTrue(contains(source,'displayFloor = 1e-5'));
            testCase.verifyTrue(contains(source,'displayCeiling = 1'));
            testCase.verifyTrue(contains(source, ...
                'connected(raw<displayFloor) = NaN'));
            testCase.verifyTrue(contains(source, ...
                'Exact-zero floor markers are shown but not connected'));
        end

        function fivePointPlotKeepsTheoryAndOrderingHonest(testCase)
            source = fileread(fullfile(fileparts(mfilename('fullpath')), ...
                'plotSenloraSymmetricV8FivePointReview.m'));
            testCase.verifyTrue(contains(source, ...
                'targetTimeSec = [-366;-274.5;-183;-91.5;0]'));
            testCase.verifyTrue(contains(source,'theory.snrDb+21'));
            testCase.verifyTrue(contains(source, ...
                'selected.jointSer>=selected.idealSer'));
            testCase.verifyTrue(contains(source, ...
                'EXP5V8:FivePointOrdering'));
            testCase.verifyTrue(contains(source, ...
                'repmat(theorySer,numel(targetTimeSec),1)'));
            testCase.verifyTrue(contains(source,'''o'',''v'',9'));
            testCase.verifyTrue(contains(source,'''^'',''x'',7'));
        end

        function freshFivePointRunnerHasFixedScope(testCase)
            source = fileread(fullfile(fileparts(mfilename('fullpath')), ...
                'runSenloraSymmetricV8FivePoint1000.m'));
            testCase.verifyTrue(contains(source, ...
                'targetTimeSec = [-366;-274.5;-183;-91.5;0]'));
            testCase.verifyTrue(contains(source,'packetCount = 1000'));
            testCase.verifyTrue(contains(source,'rootSeed = 1032500000'));
            testCase.verifyTrue(contains(source,'''five-point-1000'''));
            testCase.verifyTrue(contains(source,'senloraSymmetricV8Decode'));
            testCase.verifyTrue(contains(source,'exp1IdealDecode'));
            testCase.verifyTrue(contains(source,'allPointsNonzero'));
            testCase.verifyTrue(contains(source, ...
                'allSenloraNotBetterThanIdeal'));
            testCase.verifyFalse(contains(source,'plan.formalRootSeed'));
        end
    end
end

function common = localStaticBootstrap(c)
model = [0.23 1.1 0];
starts = (0:c.bootstrapPilotCount-1).';
centers = starts+0.5;
common = struct( ...
    'phaseModelCycles',model, ...
    'epsilonHatBins',model(2), ...
    'coarseCfoBins',round(model(2)), ...
    'integerCfoBin',round(model(2)), ...
    'cfoBins',model(2)+model(3)*centers, ...
    'phaseRad',angle(exp(1i*2*pi*(model(1)+model(2)*starts))), ...
    'rateBinsPerSec',0, ...
    'jointRateBinsPerSec',0, ...
    'joint',struct('betaCycles',[model(1);0;0], ...
        'rateBinsPerSec',0,'centerCfoBins',model(2)+0*centers, ...
        'startPhaseRad',angle(exp(1i*2*pi*(model(1)+ ...
        model(2)*starts)))), ...
    'usesPayloadTruth',false,'usesOrbitTruth',false);
end
