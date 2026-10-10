classdef SenloraPaperPointTest < matlab.unittest.TestCase
    methods (Test)
        function protocolAndImmediateUpdates(testCase)
            config = localConfig();
            c = config.parent;
            layout = senloraPaperPointFrameLayout(c);
            testCase.verifyEqual(layout.physicalSymbolCount,160);
            testCase.verifyEqual(layout.totalSamples,160.25*c.samplesPerSymbol);
            testCase.verifyEqual(layout.downchirpRows,[9;10]);
            testCase.verifyEqual(layout.midambleAfterDataIndex,[(3:3:111).';112]);
            testCase.verifyEqual(layout.dataStartTimeSec(1),10.25*c.symbolDurationSec,'AbsTol',1e-12);
            payload = v4GeneratePayload(c,31313);
            rx = localSamples(c,layout,payload.physicalBins,5,7);
            result = senloraPaperMidamblePointDecode(struct('rxPhysical',rx,'layout',layout),c);
            testCase.verifyEqual(result.initialCfoBins,5);
            testCase.verifyEqual(result.midambleResidualBins(1),2);
            testCase.verifyEqual(result.estimatedCfoBins(1:3),repmat(5,3,1));
            testCase.verifyEqual(result.estimatedCfoBins(4:end),repmat(7,109,1));
            testCase.verifyEqual(result.detectedPhysicalBins(4:end),payload.physicalBins(4:end));
            testCase.verifyEqual(result.pilotFirstEffectiveDataIndex(1),4);
            testCase.verifyTrue(isnan(result.pilotFirstEffectiveDataIndex(end)));
            testCase.verifyFalse(result.usesDopplerRate || result.usesPayloadFeedback || result.usesSnrInput);
        end
        function signedPointAcquisitionAndPerfectConstantCfo(testCase)
            config = localConfig(); c = config.parent;
            layout = senloraPaperPointFrameLayout(c);
            payload = v4GeneratePayload(c,31314);
            for cfo = [-23,23]
                rx = localSamples(c,layout,payload.physicalBins,cfo,cfo);
                result = senloraPaperMidamblePointDecode(struct('rxPhysical',rx,'layout',layout),c);
                testCase.verifyEqual(result.initialCfoBins,cfo);
                testCase.verifyEqual(result.detectedPhysicalBins,payload.physicalBins);
                testCase.verifyEqual(result.midambleResidualBins,zeros(38,1));
            end
        end
        function noiseAndChannelPairing(testCase)
            config = localConfig(); c = config.parent;
            seeds = struct('payloadSeed',31401,'noiseSeed',31402, ...
                'channelSeed',31403,'paperExtraNoiseSeed',31404);
            for channel = ["AWGN","Rician"]
                if channel=="AWGN"
                    native = senloraSymmetricV8GenerateFrame(config,0,-21.12,seeds);
                    h = 1;
                else
                    native = senloraSymmetricV8GenerateRicianFrame(config,0,-21.12,seeds);
                    h = native.truth.channelCoefficient;
                end
                paper = senloraPaperPointGenerateFrame(config,0,-21.12,seeds,char(channel));
                testCase.verifyEqual(paper.truth.channelCoefficient,h);
                testCase.verifyEqual(paper.truth.payloadPhysicalBins,native.truth.payloadPhysicalBins);
                testCase.verifyEqual(paper.observation.rxPhysical(1:8,:),native.observation.rxPhysical(1:8,:));
                a = localNoise(native,c,h); b = localNoise(paper,c,h);
                testCase.verifyEqual(b(paper.observation.layout.dataRows,:), ...
                    a(native.observation.layout.dataRows,:),'AbsTol',1e-12);
                testCase.verifySize(paper.observation.rxQuarterSync,[1,1024]);
                ideal = exp1IdealDecode(paper,config);
                testCase.verifySize(ideal.detectedPhysicalBins,[112,1]);
            end
        end
        function exactAwgnTheoryMatchesFrozenTable(testCase)
            config = localConfig();
            path = fullfile(fileparts(config.projectRoot),'Lora(theory)', ...
                'ideal_stage55_ser','results','ideal_ser_theory.csv');
            data = readtable(path);
            selected = data(ismember(data.snrDb,[-30 -25 -21]),:);
            actual = senloraSymmetricV8AwgnTheory(12,selected.snrDb);
            testCase.verifyEqual(actual,selected.ser,'RelTol',1e-6,'AbsTol',1e-11);
        end
    end
end
function config = localConfig()
here = fileparts(mfilename('fullpath'));
addpath(fullfile(here,'..','scripts')); exp1SetupPaths(); addpath(here);
config = exp1Config();
end
function rx = localSamples(c,layout,bins,initialCfo,payloadCfo)
m = c.samplesPerSymbol;
rx = complex(zeros(layout.physicalSymbolCount,m));
allBins = zeros(layout.physicalSymbolCount,1); allBins(layout.dataRows) = bins;
for row = 1:layout.physicalSymbolCount
    chirp = v4ModulateSymbol(allBins(row),c);
    if layout.kind(row)=="downchirp", chirp = conj(chirp); end
    if row<=10, cfo = initialCfo; else, cfo = payloadCfo; end
    rx(row,:) = chirp.*exp(1i*2*pi*cfo*(0:m-1)/m);
end
end
function noise = localNoise(frame,c,h)
layout = frame.observation.layout;
allBins = zeros(layout.physicalSymbolCount,1);
allBins(layout.dataRows) = frame.truth.payloadPhysicalBins;
tx = complex(zeros(size(frame.observation.rxPhysical)));
for row = 1:layout.physicalSymbolCount
    tx(row,:) = v4ModulateSymbol(allBins(row),c);
    if layout.kind(row)=="downchirp", tx(row,:) = conj(tx(row,:)); end
end
noise = frame.observation.rxPhysical-h*tx.*exp(1i*frame.truth.phasePhysicalRad);
end
