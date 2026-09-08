function [bestBits, bestNibble, bestScore] = softHammingDecodeOne(llr, cr)
%SOFTHAMMINGDECODEONE Algorithm 1 from the SenLoRa paper.

arguments
    llr (1,:) double
    cr (1,1) double {mustBeInteger, mustBeMember(cr, [1 2 3 4])}
end

codeLength = 4 + cr;
if numel(llr) ~= codeLength
    error("SenLoRa:InvalidLlrLength", ...
        "LLR vector length must equal 4 + CR.");
end

codeTable = hammingCodeTable(cr);
candidateScores = zeros(numel(codeTable), 1);
candidateBits = false(numel(codeTable), codeLength);
hardBits = llr > 0;

for idx = 1:numel(codeTable)
    bits = codewordBits(codeTable(idx), cr);
    sameMask = bits == hardBits;
    diffMask = ~sameMask;
    probSame = sum(abs(llr(sameMask)) .^ 2);
    probDiff = sum(abs(llr(diffMask)) .^ 2);
    candidateScores(idx) = probSame - probDiff;
    candidateBits(idx, :) = bits;
end

[bestScore, bestIdx] = max(candidateScores);
bestBits = candidateBits(bestIdx, :);
bestNibble = bestIdx - 1;

end

