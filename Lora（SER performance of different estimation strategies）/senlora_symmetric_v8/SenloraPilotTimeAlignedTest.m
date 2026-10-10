classdef SenloraPilotTimeAlignedTest < matlab.unittest.TestCase
    methods (Test)
        function signedFractionalCfoAndVariantFlags(testCase)
            config = localConfig(); c = config.parent;
            layout = senloraPaperPointFrameLayout(c);
            payload = v4GeneratePayload(c,32001);
            for cfo = [-23.4375,23.3125]
                rx = localSamples(c,layout,payload.physicalBins, ...
                    repmat(cfo,layout.physicalSymbolCount,1));
                result = senloraPilotTimeAlignedDecode(struct('rxPhysical',rx,'layout',layout),c);
                testCase.verifyEqual(result.detectedPhysicalBins,payload.physicalBins);
                testCase.verifyEqual(result.estimatedCfoBins,repmat(cfo,112,1),'AbsTol',1e-12);
                testCase.verifyTrue(result.usesFuturePilot && result.usesPilotTimeInterpolation);
                testCase.verifyFalse(result.isOriginalPaperThirdMethod || result.usesWithinSymbolRate);
                testCase.verifyFalse(result.usesPayloadTruth || result.usesOrbitTruth || ...
                    result.usesSnrInput || result.usesTargetSer || result.usesPayloadFeedback);
            end
        end
        function exactLinearRampAndFrameCenterWeights(testCase)
            config = localConfig(); c = config.parent;
            layout = senloraPaperPointFrameLayout(c);
            payload = v4GeneratePayload(c,32002);
            normalizedTime = layout.physicalCenterTimeSec/c.symbolDurationSec;
            cfo = 17-0.25*(normalizedTime-normalizedTime(layout.downchirpRows(end)));
            rx = localSamples(c,layout,payload.physicalBins,cfo);
            result = senloraPilotTimeAlignedDecode(struct('rxPhysical',rx,'layout',layout),c);
            testCase.verifyEqual(result.pilotInterpolationWeight(1),5/9,'AbsTol',1e-12);
            testCase.verifyEqual(result.pilotInterpolationWeight(2:end),repmat(0.5,111,1),'AbsTol',1e-12);
            testCase.verifyEqual(result.estimatedCfoBins,cfo(layout.dataRows),'AbsTol',1e-11);
            testCase.verifyEqual(result.detectedPhysicalBins,payload.physicalBins);
            testCase.verifyEqual(result.leftPilotRows, ...
                [layout.downchirpRows(end);layout.midambleRows(1:end-1)]);
            testCase.verifyEqual(result.rightPilotRows,layout.midambleRows);
        end
        function terminalPilotAffectsOnlyFinalDataAndWrapIsLocal(testCase)
            config = localConfig(); c = config.parent;
            layout = senloraPaperPointFrameLayout(c);
            payload = v4GeneratePayload(c,32003);
            cfo = repmat(2,layout.physicalSymbolCount,1);
            a = senloraPilotTimeAlignedDecode(struct('rxPhysical', ...
                localSamples(c,layout,payload.physicalBins,cfo),'layout',layout),c);
            cfo(layout.midambleRows(end)) = 2.125;
            b = senloraPilotTimeAlignedDecode(struct('rxPhysical', ...
                localSamples(c,layout,payload.physicalBins,cfo),'layout',layout),c);
            testCase.verifyEqual(a.estimatedCfoBins(1:111),b.estimatedCfoBins(1:111));
            testCase.verifyEqual(b.estimatedCfoBins(end),2.0625,'AbsTol',1e-12);
            cfo = repmat(c.samplesPerSymbol/2-0.125,layout.physicalSymbolCount,1);
            cfo(layout.midambleRows) = -c.samplesPerSymbol/2+0.125;
            wrapped = senloraPilotTimeAlignedDecode(struct('rxPhysical', ...
                localSamples(c,layout,payload.physicalBins,cfo),'layout',layout),c);
            testCase.verifyEqual(wrapped.estimatedCfoBins(1), ...
                c.samplesPerSymbol/2-0.125+(5/9)*0.25,'AbsTol',1e-11);
        end
        function noNoiseOrbitSweepAndTruthMetadataIsolation(testCase)
            config = localConfig(); c = config.parent;
            seeds = struct('payloadSeed',32004,'noiseSeed',32005, ...
                'channelSeed',32006,'paperExtraNoiseSeed',32007);
            for time = [-366,-274.5,-183,-91.5,0]
                frame = senloraPaperPointGenerateFrame(config,time,Inf,seeds,'AWGN');
                a = senloraPilotTimeAlignedDecode(frame.observation,c);
                testCase.verifyEqual(a.detectedPhysicalBins,frame.truth.payloadPhysicalBins);
                testCase.verifyLessThan(max(abs(frame.truth.dataCfoBins-a.estimatedCfoBins)),0.04);
                altered = frame.observation;
                altered.noiseVariance = 1e100;
                altered.orbitStartSec = 999;
                altered.trueCfoBins = repmat(999,112,1);
                altered.payloadTruth = zeros(112,1);
                altered.snrDb = 999;
                altered.targetSer = 0;
                b = senloraPilotTimeAlignedDecode(altered,c);
                testCase.verifyEqual(b.detectedPhysicalBins,a.detectedPhysicalBins);
                testCase.verifyEqual(b.estimatedCfoBins,a.estimatedCfoBins);
            end
        end
    end
end
function config = localConfig()
here = fileparts(mfilename('fullpath'));
addpath(fullfile(here,'..','scripts')); exp1SetupPaths(); addpath(here);
config = exp1Config();
end
function rx = localSamples(c,layout,bins,cfo)
m = c.samplesPerSymbol;
allBins = zeros(layout.physicalSymbolCount,1); allBins(layout.dataRows) = bins;
rx = complex(zeros(layout.physicalSymbolCount,m));
for row = 1:layout.physicalSymbolCount
    chirp = v4ModulateSymbol(allBins(row),c);
    if layout.kind(row)=="downchirp", chirp = conj(chirp); end
    rx(row,:) = chirp.*exp(1i*2*pi*cfo(row)*(0:m-1)/m);
end
end
