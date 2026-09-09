function candidates=v4BCalibrationCandidates()
base=v4DefaultBParameters();base.candidateIndex=0;decision=[1.01 1.10 1.20 1.50];residual=[1.01 1.05];innovation=[0.50 0.75];margin=[0 0.10];candidates=repmat(base,32,1);row=0;for a=1:4,for b=1:2,for d=1:2,for e=1:2,row=row+1;candidates(row)=base;candidates(row).decisionPeakRatioThreshold=decision(a);candidates(row).residualPeakRatioThreshold=residual(b);candidates(row).innovationLimitBins=innovation(d);candidates(row).softHammingMarginRatio=margin(e);candidates(row).candidateIndex=row;end,end,end,end
end
