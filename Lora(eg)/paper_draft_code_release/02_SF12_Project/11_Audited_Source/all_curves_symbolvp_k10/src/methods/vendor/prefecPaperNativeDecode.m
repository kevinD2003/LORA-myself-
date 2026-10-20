function result=prefecPaperNativeDecode(observation,c,options)
%PREFECPAPERNATIVEDECODE User PaperV6 adaptation, isolated pre-FEC corrections.
% Existing observable selector/trend fit remain. Numerical Fourier-peak
% refinement and immediate received-pilot updates are explicit switches.
arguments
    observation (1,1) struct
    c (1,1) struct
    options.RefinePoints (1,1) logical = true
    options.ImmediateUpdate (1,1) logical = true
end
assert(c.dataBinSpacing==1 && c.payloadSymbolCount==112 && c.cr==3);
layout=observation.layout; m=c.samplesPerSymbol;
% Preserve the SF12 physical rate prior (20*125000/4096 Hz/s) at both SFs.
% A fixed bin/s prior is 32 times too broad when transferred to SF7.
maximumRate=20;
if options.RefinePoints, maximumRate=20*m/4096; end
% Keep the existing mode classifier and its 1-bin/s search grid unchanged.
% Only the causal estimator's rate prior is converted to physical units.
parameters=struct('maximumRateBinsPerSec',20,'modeLargeToCentralRatio',.75);
mode=v4Stage55ObservableModeSelectorV10(observation.rxPhysical(1:c.bootstrapPilotCount,:),c,parameters);
dynamic=~mode.staticSelected;
last=layout.bootstrapRows(end);
if options.RefinePoints
    initial=localFourierPoint(observation.rxPhysical(last,:),c);
elseif dynamic
    a=v4PaperRefinedPointEstimate(observation.rxPhysical(last,:),0,c); initial=a.offsetBins;
else
    a=v4PaperIntegerPointEstimate(observation.rxPhysical(last,:),0,c); initial=a.offsetBins;
end
anchor=initial; anchorTime=layout.physicalCenterTimeSec(last); rate=0;
historyTime=anchorTime; historyCfo=anchor;
if options.RefinePoints
    historyTime=layout.physicalCenterTimeSec(layout.bootstrapRows);
    historyCfo=zeros(numel(layout.bootstrapRows),1);
    for b=1:numel(layout.bootstrapRows)
        historyCfo(b)=localFourierPoint(observation.rxPhysical(layout.bootstrapRows(b),:),c);
    end
    if dynamic
        slopes=zeros(28,1); count=0;
        for j=2:numel(historyTime)
            for i=1:j-1, count=count+1; slopes(count)=(historyCfo(j)-historyCfo(i))/(historyTime(j)-historyTime(i)); end
        end
        rate=min(maximumRate,max(-maximumRate,median(slopes(1:count))));
        anchor=median(historyCfo-rate*(historyTime-anchorTime));
    else
        anchor=median(historyCfo);
    end
    keep=abs(historyCfo-(anchor+rate*(historyTime-anchorTime)))<=.5;
    if nnz(keep)>=2, historyTime=historyTime(keep); historyCfo=historyCfo(keep); end
    initial=anchor;
end
pendingCfo=NaN; pendingTime=NaN; pendingRate=NaN; remaining=0;
delay=2*double(dynamic && ~options.ImmediateUpdate);
samples=complex(zeros(112,m)); estimates=nan(112,1); rates=nan(112,1);
measures=nan(c.paperMidambleCount,1); pilotRates=measures; firstEffective=measures;
pilot=0;
for row=c.bootstrapPilotCount+1:layout.physicalSymbolCount
    center=layout.physicalCenterTimeSec(row);
    prediction=anchor;
    if dynamic, prediction=anchor+rate*(center-anchorTime); end
    compensated=v4CompensateSymbol(observation.rxPhysical(row,:),0,prediction,rate,c);
    if layout.kind(row)=="data"
        k=layout.dataIndex(row); samples(k,:)=compensated; estimates(k)=prediction; rates(k)=rate;
        if remaining>0
            remaining=remaining-1;
            if remaining==0, anchor=pendingCfo; anchorTime=pendingTime; rate=pendingRate; end
        end
    elseif layout.kind(row)=="midamble"
        pilot=pilot+1;
        accepted=true;
        if dynamic
            residual=v4PaperLocalResidualEstimate(compensated,c,maximumRate);
            offset=residual.offsetBins;
            if options.RefinePoints, offset=localFourierPoint(compensated,c,residual.offsetBins); end
            measured=prediction+offset;
            accepted=residual.globalFftPeakRatio>=1.5;
            if accepted || ~options.RefinePoints
                historyTime(end+1,1)=center; historyCfo(end+1,1)=measured; %#ok<AGROW>
                if numel(historyTime)>8, historyTime=historyTime(end-7:end); historyCfo=historyCfo(end-7:end); end
                [fitted,newRate]=localFit(historyTime,historyCfo,center,maximumRate);
            end
            if accepted, nextCfo=fitted; nextRate=newRate;
            elseif options.RefinePoints, nextCfo=prediction; nextRate=rate;
            else, nextCfo=measured; nextRate=0; end
        else
            if options.RefinePoints
                local=v4PaperLocalResidualEstimate(compensated,c,maximumRate);
                offset=localFourierPoint(compensated,c,local.offsetBins);
            else, a=v4PaperIntegerPointEstimate(compensated,0,c); offset=a.offsetBins; end
            measured=prediction+offset; nextCfo=measured; nextRate=0;
        end
        measures(pilot)=measured; pilotRates(pilot)=nextRate;
        next=layout.midambleAfterDataIndex(pilot)+delay+1;
        if next<=112 && (accepted || ~options.RefinePoints), firstEffective(pilot)=next; end
        if delay==0
            anchor=nextCfo; anchorTime=center; rate=nextRate;
        else
            pendingCfo=nextCfo; pendingTime=center; pendingRate=nextRate; remaining=delay;
        end
    end
end
hard=prefecNativeHardDetect(samples,c);
result=struct('detectedPhysicalBins',hard.detectedPhysicalBins, ...
    'estimatedCfoBins',estimates,'estimatedRateBinsPerSec',rates, ...
    'midamblePointCfoBins',measures,'midambleRateBinsPerSec',pilotRates, ...
    'pilotFirstEffectiveDataIndex',firstEffective,'initialCfoBins',initial, ...
    'usesFecDecoding',false,'symbolSource',hard.symbolSource, ...
    'usesPayloadFeedback',false,'usesPayloadTruth',false,'usesOrbitTruth',false, ...
    'usesCaseIdentity',false,'usesSnrInput',false,'usesTargetSer',false, ...
    'usesFuturePilot',false,'usesDopplerRate',dynamic,'modeEvidence',mode, ...
    'usesAllKnownPreambleForInitialization',options.RefinePoints, ...
    'weakPilotRetainsCausalPrediction',options.RefinePoints, ...
    'dynamicSelected',dynamic,'refinePoints',options.RefinePoints, ...
    'immediateUpdate',options.ImmediateUpdate,'midambleUpdateDelayDataSymbols',delay, ...
    'maximumRateBinsPerSec',maximumRate, ...
    'maximumRateHzPerSec',maximumRate*c.fftBinSpacingHz, ...
    'dataFftPadding',1,'dataBinSpacing',1,'noLdro',true, ...
    'methodCore','user-PaperV6-observable-static-or-causal-trend-adaptation');
end

function frequency=localFourierPoint(rx,c,localAnchor)
m=c.samplesPerSymbol; up=v4ModulateSymbol(0,c); x=rx.*conj(up);
if nargin<3
    [~,index]=max(abs(fft(x,16*m)).^2); frequency=index-1;
    if frequency>=8*m, frequency=frequency-16*m; end
    frequency=frequency/16; radius=1/16;
else
    % Preserve the user's causal local residual search. A global FFT peak
    % can be an unrelated noise maximum and must not replace that prior.
    frequency=localAnchor; radius=.25;
end
anchor=frequency;
n=(0:m-1)/m; d=-1i*2*pi*n;
for k=1:3
    z=x.*exp(-1i*2*pi*frequency*n); y=sum(z); dy=sum(d.*z); ddy=sum(d.^2.*z);
    gradient=2*real(conj(y)*dy); curvature=2*(real(conj(y)*ddy)+abs(dy)^2);
    if ~isfinite(curvature) || curvature>=0, break; end
    next=min(max(frequency-gradient/curvature,anchor-radius),anchor+radius);
    if abs(sum(x.*exp(-1i*2*pi*next*n)))^2<abs(y)^2, break; end
    if abs(next-frequency)<1e-10, frequency=next; break; end
    frequency=next;
end
end

function [cfo,rate]=localFit(time,measurement,target,maximumRate)
x=time-target; design=[ones(size(x)) x]; weight=ones(size(x)); beta=design\measurement;
for k=1:2
    residual=measurement-design*beta; weight=min(1,.5./max(abs(residual),eps));
    rootWeight=sqrt(weight); beta=(design.*rootWeight)\(measurement.*rootWeight);
end
rate=min(maximumRate,max(-maximumRate,beta(2))); cfo=sum(weight.*(measurement-rate*x))/sum(weight);
end
