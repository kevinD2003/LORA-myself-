function confidence=v4Stage55Confidence(decoded,config,parameters)
%V4STAGE55CONFIDENCE Project-aligned squared-codeword amendment and EMA.
score=nan(config.payloadSymbolCount,1);tauBlock=nan(config.payloadSymbolCount,1);tauGlobal=nan(config.payloadSymbolCount,1);confident=false(config.payloadSymbolCount,1);globalTau=NaN;table=v4Hamming74Table();mix=0.5;if isfield(parameters,'confidenceMix'),mix=parameters.confidenceMix;end
for block=1:config.hammingBlockCount
    rows=(block-1)*7+(1:7);raw=decoded.rawCodeLlr(:,:,block);data=double(decoded.confidenceDataBits(:,:,block));parity=mod([data(:,1)+data(:,2)+data(:,4),data(:,1)+data(:,3)+data(:,4),data(:,2)+data(:,3)+data(:,4)],2);code=[data parity];
    amended=zeros(12,7);
    for r=1:12
        reliability=sqrt(max(decoded.codewordMargin(r,block),0)/7);target=(2*code(r,:)-1).*max(abs(raw(r,:)),reliability);amended(r,:)=(1-mix)*raw(r,:)+mix*target;
    end
    symbolLlr=zeros(7,12);for column=1:7,for bit=1:12,symbolLlr(column,bit)=amended(mod(bit+column-2,12)+1,column);end,end
    localScore=sum(abs(symbolLlr).^2,2);localTau=mean(localScore)+std(localScore,0);if ~isfinite(globalTau),globalTau=localTau;else,globalTau=parameters.confidenceAlpha*globalTau+(1-parameters.confidenceAlpha)*localTau;end
    score(rows)=localScore;tauBlock(rows)=localTau;tauGlobal(rows)=globalTau;marginRatio=decoded.symbolCodewordMargin(rows)/max(globalTau,eps);confident(rows)=localScore>=parameters.confidenceThresholdScale*globalTau&marginRatio>=parameters.softHammingMarginRatio;
end
if parameters.requireSoftHardAgreement,confident=confident&decoded.confidenceReencodedPhysicalBins==decoded.hardPhysicalBins;end
confidence=struct('score',score,'tauBlock',tauBlock,'tauGlobal',tauGlobal,'confidentMask',confident,'hardPhysicalBins',decoded.hardPhysicalBins,'confidenceMetric','squared-codeword-amended-llr','hammingTableHash',v4Sha256(v4CanonicalJson(table)));
end
