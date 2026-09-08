function pass = satelliteFig3SenLoRaConfidence(compensatedSymbols, config, options)
%SATELLITEFIG3SENLORACONFIDENCE SenLoRa soft confidence on 7-symbol blocks.
%   Implements FFT-energy probabilities, Gray-bit LLRs, soft Hamming(7,4),
%   symbol sum-|LLR|^2 confidence, and the paper's block/EMA thresholds.

arguments
    compensatedSymbols (:,:) double
    config (1,1) struct
    options.PreviousTauGlobal (1,1) double = NaN
    options.AmendLlrMix (1,1) double {mustBeGreaterThanOrEqual(options.AmendLlrMix,0),mustBeLessThanOrEqual(options.AmendLlrMix,1)} = 0.5
end

nSymbols = size(compensatedSymbols,1);
m = config.samplesPerSymbol;
if size(compensatedSymbols,2) ~= m
    error('SatelliteFig3:ConfidenceShape','Expected one complete CSS symbol per row.');
end
bootstrapCount = config.bootstrapPilotCount;
blockLength = 4+config.cr;
if blockLength ~= 7
    error('SatelliteFig3:ConfidenceCoding','This implementation currently supports CR=3.');
end
grayBits = localGrayBitTable(config.sf);
hardBins = nan(nSymbols,1);
spectra = complex(zeros(nSymbols,m));
for row = 1:nSymbols
    hard = satelliteFig3HardDecision(compensatedSymbols(row,:),config);
    hardBins(row) = hard.waveformBin;
    spectra(row,:) = hard.spectrum.';
end
preamblePower = abs(spectra(1:bootstrapCount,:)).^2;
noisePower = max(mean(preamblePower(:,2:end),'all'),eps);

confidence = nan(nSymbols,1);
tauBlock = nan(nSymbols,1);
tauGlobal = nan(nSymbols,1);
ready = false(nSymbols,1);
confident = false(nSymbols,1);
decodedWaveformBins = hardBins;
decodedGrayLabels = nan(nSymbols,1);
symbolLlr = nan(nSymbols,config.sf);
symbolCodewordMargin = nan(nSymbols,1);
symbolCodewordScore = nan(nSymbols,1);
globalTau = options.PreviousTauGlobal;
payloadStart = bootstrapCount+1;
blockCount = floor((nSymbols-bootstrapCount)/blockLength);
decodedDataBits = nan(config.sf,4,blockCount);
for block = 1:blockCount
    rows = payloadStart-1+(block-1)*blockLength+(1:blockLength);
    llrSymbols = zeros(blockLength,config.sf);
    for row = 1:blockLength
        energy = abs(spectra(rows(row),:)).^2;
        logits = energy/noisePower;
        logProbability = logits-(max(logits)+log(sum(exp(logits-max(logits)))));
        for bit = 1:config.sf
            one = grayBits(:,bit).';
            llrSymbols(row,bit) = localLogSumExp(logProbability(one))- ...
                localLogSumExp(logProbability(~one));
        end
    end
    codeLlr = localDeinterleaveLlr(llrSymbols,config.sf);
    [decodedCode,score,scoreMargin] = localSoftDecode(codeLlr);
    decodedDataBits(:,:,block) = double(decodedCode(:,1:4));
    amendedCode = localAmendLlr(codeLlr,decodedCode,scoreMargin,options.AmendLlrMix);
    [amendedSymbols,blockGrayLabels,blockSymbolMargin,blockSymbolScore] = ...
        localInterleaveCodeLlr(amendedCode,decodedCode,scoreMargin,score,config.sf);
    blockConfidence = sum(abs(amendedSymbols).^2,2);
    blockTau = mean(blockConfidence)+std(blockConfidence,0);
    if ~isfinite(globalTau)
        globalTau = blockTau;
    else
        globalTau = config.confidenceAlpha*globalTau + ...
            (1-config.confidenceAlpha)*blockTau;
    end
    confidence(rows) = blockConfidence;
    tauBlock(rows) = blockTau;
    tauGlobal(rows) = globalTau;
    ready(rows) = true;
    confident(rows) = blockConfidence >= config.confidenceThresholdScale*globalTau;
    symbolLlr(rows,:) = amendedSymbols;
    symbolCodewordMargin(rows) = blockSymbolMargin;
    symbolCodewordScore(rows) = blockSymbolScore;
    decodedGrayLabels(rows) = blockGrayLabels;
    rawFft = double(satelliteFig3GrayDecode(uint32(blockGrayLabels)));
    decodedWaveformBins(rows) = rawFft;
end

pass = struct( ...
    'hardWaveformBins',hardBins, ...
    'decodedWaveformBins',decodedWaveformBins, ...
    'decodedGrayLabels',decodedGrayLabels, ...
    'confidence',confidence, 'symbolLlr',symbolLlr, ...
    'symbolCodewordMargin',symbolCodewordMargin, ...
    'symbolCodewordScore',symbolCodewordScore, ...
    'decodedDataBits',decodedDataBits, ...
    'tauBlock',tauBlock, 'tauGlobal',tauGlobal, ...
    'finalTauGlobal',globalTau, 'confidentMask',confident, ...
    'readyMask',ready, 'noisePower',noisePower, ...
    'completedBlockCount',blockCount, 'softScorePlaceholder',NaN);
end

function table = localGrayBitTable(sf)
m = 2^sf;
table = false(m,sf);
for raw = 0:m-1
    gray = satelliteFig3GrayEncode(uint32(raw));
    for bit = 1:sf
        table(raw+1,bit) = bitget(gray,bit) ~= 0;
    end
end
end

function codeLlr = localDeinterleaveLlr(symbolLlr,sf)
columnCount = size(symbolLlr,1);
codeLlr = zeros(sf,columnCount);
for column = 1:columnCount
    for bit = 1:sf
        codeLlr(mod(bit+column-2,sf)+1,column) = symbolLlr(column,bit);
    end
end
end

function [symbolLlr,grayLabels,symbolMargin,symbolScore] = localInterleaveCodeLlr(codeLlr,codeBits,codewordMargin,codewordScore,sf)
columnCount = size(codeLlr,2);
symbolLlr = zeros(columnCount,sf);
grayLabels = zeros(columnCount,1);
symbolMargin = zeros(columnCount,1);
symbolScore = zeros(columnCount,1);
for column = 1:columnCount
    label = uint32(0);
    participatingRows = zeros(sf,1);
    for bit = 1:sf
        row = mod(bit+column-2,sf)+1;
        participatingRows(bit) = row;
        symbolLlr(column,bit) = codeLlr(row,column);
        if codeBits(row,column)
            label = bitor(label,bitshift(uint32(1),bit-1));
        end
    end
    grayLabels(column) = double(label);
    % A CSS symbol is trusted only if every deinterleaved codeword decision
    % feeding its Gray label has a clear best-versus-runner-up Hamming score.
    % The minimum is deliberately conservative; this is a receiver-visible
    % quality value, never a transmitted-label oracle.
    symbolMargin(column) = min(codewordMargin(participatingRows));
    symbolScore(column) = min(codewordScore(participatingRows));
end
end

function [decoded,score,margin] = localSoftDecode(codeLlr)
[sf,codeLength] = size(codeLlr);
decoded = false(sf,codeLength);
score = zeros(sf,1);
margin = zeros(sf,1);
table = localHamming74Table();
for row = 1:sf
    llr = codeLlr(row,:);
    hard = llr > 0;
    candidateScore = zeros(16,1);
    for candidate = 1:16
        same = table(candidate,:) == hard;
        candidateScore(candidate) = sum(abs(llr(same)).^2)-sum(abs(llr(~same)).^2);
    end
    [ordered,indices] = sort(candidateScore,'descend');
    decoded(row,:) = table(indices(1),:);
    score(row) = ordered(1);
    margin(row) = ordered(1)-ordered(2);
end
end

function table = localHamming74Table()
table = false(16,7);
for value = 0:15
    d = bitget(uint32(value),4:-1:1) ~= 0;
    p = mod([double(d(1))+double(d(2))+double(d(4)), ...
        double(d(1))+double(d(3))+double(d(4)), ...
        double(d(2))+double(d(3))+double(d(4))],2) ~= 0;
    table(value+1,:) = [d,p];
end
end

function amended = localAmendLlr(codeLlr,decoded,margin,mix)
amended = codeLlr;
for row = 1:size(codeLlr,1)
    signBits = 2*double(decoded(row,:))-1;
    decodedReliability = sqrt(max(margin(row),0)/size(codeLlr,2));
    target = signBits.*max(abs(codeLlr(row,:)),decodedReliability);
    amended(row,:) = (1-mix)*codeLlr(row,:)+mix*target;
end
end

function value = localLogSumExp(x)
maximum = max(x);
value = maximum+log(sum(exp(x-maximum)));
end
