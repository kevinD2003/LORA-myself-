function confidence = v3Stage55Confidence(decoded,config,parameters)
%V3STAGE55CONFIDENCE Block-causal soft-Hamming confidence and EMA gate.

score = sum(abs(decoded.bitLlr).^2,2);
tauBlock = nan(config.payloadSymbolCount,1);
tauGlobal = nan(config.payloadSymbolCount,1);
confident = false(config.payloadSymbolCount,1);
globalTau = NaN;
for block = 1:config.hammingBlockCount
    rows = (block-1)*config.hammingCodewordLength+(1:config.hammingCodewordLength);
    localTau = mean(score(rows))+std(score(rows),0);
    if ~isfinite(globalTau)
        globalTau = localTau;
    else
        globalTau = parameters.confidenceAlpha*globalTau+ ...
            (1-parameters.confidenceAlpha)*localTau;
    end
    tauBlock(rows) = localTau;
    tauGlobal(rows) = globalTau;
    marginRatio = decoded.symbolCodewordMargin(rows)/max(globalTau,eps);
    confident(rows) = score(rows) >= parameters.confidenceThresholdScale*globalTau & ...
        marginRatio >= parameters.softHammingMarginRatio;
end
if parameters.requireSoftHardAgreement
    confident = confident & ...
        decoded.softReencodedPhysicalBins == decoded.hardPhysicalBins;
end
confidence = struct('score',score,'tauBlock',tauBlock, ...
    'tauGlobal',tauGlobal,'confidentMask',confident, ...
    'hardPhysicalBins',decoded.hardPhysicalBins);
end
