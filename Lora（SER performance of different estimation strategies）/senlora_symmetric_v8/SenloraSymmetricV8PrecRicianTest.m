classdef SenloraSymmetricV8PrecRicianTest < matlab.unittest.TestCase
    methods (Test)
        function existingReceiverHashesMatch(testCase)
            config = localConfig();
            manifest = jsondecode(fileread(config.parentManifestPath));
            names = {'v4HuangPrecUnifiedDecodeV9','v4HuangPrecDecodeV3','v4HuangStaticDecode'};
            for k = 1:numel(names)
                path = which(names{k});
                relative = strrep(erase(path,[config.parentRoot,filesep]),'\','/');
                entry = manifest.files(strcmp({manifest.files.path},relative));
                testCase.verifyNumElements(entry,1);
                testCase.verifyEqual(lower(exp1Sha256(path)),lower(entry.sha256));
            end
        end
        function nativeFrameReplaysSavedSameFrameIdeal(testCase)
            config = localConfig();
            c = config.parent;
            raw = readtable(fullfile(config.projectRoot,'results', ...
                'senlora_symmetric_v8','case_snr_rician_k10', ...
                'RICIAN_CASE_SNR_RAW_PACKETS.csv'));
            rows = find(raw.packetId==1 & ismember(raw.snrDb,[-30 -21]));
            for k = rows.'
                seeds = struct('payloadSeed',raw.payloadSeed(k), ...
                    'noiseSeed',raw.noiseSeed(k),'channelSeed',raw.channelSeed(k));
                f = senloraSymmetricV8GenerateRicianFrame(config, ...
                    raw.orbitStartSec(k),raw.snrDb(k),seeds);
                testCase.verifyEqual(f.observation.layout.physicalSymbolCount,120);
                testCase.verifyEmpty(f.observation.layout.midambleRows);
                testCase.verifyEqual(f.truth.channelPower,raw.channelPower(k),'AbsTol',1e-12);
                receiver = v4HuangPrecUnifiedDecodeV9(f.observation,c);
                testCase.verifySize(receiver.detectedPhysicalBins,[112,1]);
                testCase.verifyTrue(receiver.sameEntryAcrossCases);
                testCase.verifyFalse(receiver.usesOrbitTruth || receiver.usesPayloadTruth || ...
                    receiver.usesCaseIdentity || receiver.usesSnrInput || ...
                    receiver.usesDopplerRate || receiver.usesPayloadFeedback);
                testCase.verifyFalse(any(receiver.virtualPilotAccepted));
                testCase.verifyFalse(any(receiver.explicitMidambleAccepted));
                testCase.verifyEqual(receiver.estimatedCfoBins, ...
                    repmat(receiver.estimatedCfoBins(1),112,1),'AbsTol',1e-12);
                ideal = exp1IdealDecode(f,config);
                testCase.verifyEqual(sum(ideal.detectedPhysicalBins(:)~= ...
                    f.truth.payloadPhysicalBins(:)),raw.idealRawErrors(k));
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
