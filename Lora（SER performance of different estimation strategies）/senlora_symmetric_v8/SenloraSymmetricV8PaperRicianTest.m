classdef SenloraSymmetricV8PaperRicianTest < matlab.unittest.TestCase
    methods (Test)
        function rejectsInvalidReferencePoints(testCase)
            config = localConfig();
            path = fullfile(config.projectRoot,'results','senlora_symmetric_v8', ...
                'case_snr_rician_k10','RICIAN_CASE_SNR_SUMMARY.csv');
            summary = readtable(path);
            senloraSymmetricV8ValidateRicianReferenceSummary(summary,config.parent);
            fields = {'senloraSer','idealSer','exactNoDopplerRicianSer'};
            for index = 1:numel(fields)
                bad = summary;
                bad.(fields{index})(1) = NaN;
                testCase.verifyError(@() senloraSymmetricV8ValidateRicianReferenceSummary( ...
                    bad,config.parent),'EXP5V8:PaperReferenceSummary');
            end
            bad = summary;
            bad.exactNoDopplerRicianSer(1) = bad.exactNoDopplerRicianSer(1)+0.01;
            testCase.verifyError(@() senloraSymmetricV8ValidateRicianReferenceSummary( ...
                bad,config.parent),'EXP5V8:PaperReferenceSummary');
        end
        function pairedChannelPayloadAndNoise(testCase)
            config = localConfig();
            c = config.parent;
            seeds = struct('payloadSeed',3001,'noiseSeed',3002, ...
                'channelSeed',3003,'midambleNoiseSeed',3004);
            native = senloraSymmetricV8GenerateRicianFrame(config,-366,-21,seeds);
            paper = senloraSymmetricV8GeneratePaperRicianFrame(config,-366,-21,seeds);
            testCase.verifyEqual(native.truth.payloadPhysicalBins,paper.truth.payloadPhysicalBins);
            testCase.verifyEqual(native.truth.channelCoefficient,paper.truth.channelCoefficient);
            testCase.verifyEqual(native.observation.rxPhysical(1:8,:), ...
                paper.observation.rxPhysical(1:8,:));
            nativeNoise = localNoise(native,c);
            paperNoise = localNoise(paper,c);
            testCase.verifyEqual(paperNoise(paper.observation.layout.dataRows,:), ...
                nativeNoise(native.observation.layout.dataRows,:),'AbsTol',1e-12);
            testCase.verifyEqual(paper.observation.noiseVariance,10^(21/10),'AbsTol',1e-12);
            testCase.verifyEqual(numel(paper.observation.layout.midambleRows),37);
            testCase.verifyEqual(paper.observation.layout.midambleAfterDataIndex,(3:3:111).');
            testCase.verifyEqual(native.observation.layout.physicalSymbolCount,120);
            testCase.verifyEqual(paper.observation.layout.physicalSymbolCount,157);
            seeds.midambleNoiseSeed = 3005;
            changed = senloraSymmetricV8GeneratePaperRicianFrame(config,-366,-21,seeds);
            data = paper.observation.layout.dataRows;
            testCase.verifyEqual(changed.observation.rxPhysical(data,:),paper.observation.rxPhysical(data,:));
            testCase.verifyNotEqual(changed.observation.rxPhysical(paper.observation.layout.midambleRows,:), ...
                paper.observation.rxPhysical(paper.observation.layout.midambleRows,:));
        end
        function unchangedPaperEntryWorksAcrossCases(testCase)
            config = localConfig();
            c = config.parent;
            parameters = v4LoadMethodAlignedR3ParametersV1();
            seeds = struct('payloadSeed',3011,'noiseSeed',3012, ...
                'channelSeed',3013,'midambleNoiseSeed',3014);
            for start = [-366,0]
                frame = senloraSymmetricV8GeneratePaperRicianFrame(config,start,Inf,seeds);
                common = v4CommonBootstrap(frame.observation.rxPhysical(1:8,:),c, ...
                    SearchStepBins=parameters.searchStepBins);
                receiver = v4PaperMidamblePointUnifiedV6(frame.observation,common,c);
                testCase.verifySize(receiver.detectedPhysicalBins,[112,1]);
                testCase.verifyEqual(sum(receiver.explicitMidambleAccepted),37);
                testCase.verifyFalse(receiver.usesPayloadTruth || receiver.usesOrbitTruth || ...
                    receiver.usesCaseIdentity || receiver.usesSnrInput);
                testCase.verifyTrue(receiver.sameEntryAcrossCases);
                ideal = exp1IdealDecode(frame,config);
                testCase.verifyEqual(ideal.detectedPhysicalBins,frame.truth.payloadPhysicalBins);
            end
        end
    end
end
function config = localConfig()
here = fileparts(mfilename('fullpath'));
addpath(fullfile(here,'..','scripts'));
exp1SetupPaths();
addpath(here);
config = exp1Config();
end
function noise = localNoise(frame,c)
layout = frame.observation.layout;
bins = zeros(layout.physicalSymbolCount,1);
bins(layout.dataRows) = frame.truth.payloadPhysicalBins;
tx = complex(zeros(size(frame.observation.rxPhysical)));
for row = 1:layout.physicalSymbolCount, tx(row,:) = v4ModulateSymbol(bins(row),c); end
noise = frame.observation.rxPhysical-frame.truth.channelCoefficient* ...
    tx.*exp(1i*frame.truth.phasePhysicalRad);
end
