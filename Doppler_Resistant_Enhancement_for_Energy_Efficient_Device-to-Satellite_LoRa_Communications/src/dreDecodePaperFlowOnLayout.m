function result = dreDecodePaperFlowOnLayout(rawBins,layout,config,mode)
%DREDECODEPAPERFLOWONLAYOUT Causal Eq. (18)-(22) over every physical symbol.
%   The V4 shared frame contains known zero-bin bootstrap and midamble
%   symbols. A known symbol contributes its measured error directly; a data
%   symbol contributes the error implied by its current hard decision.

rawBins = double(rawBins(:));
m = config.samplesPerSymbol;
n = config.bootstrapPilotCount;
physicalCount = layout.physicalSymbolCount;
if numel(rawBins) ~= physicalCount || n < 2 || physicalCount <= n || ...
        ~isequal(layout.bootstrapRows(:),(1:n).')
    error('DRE:PaperFlowShape','Expected a complete physical V4 frame.');
end
if ~ismember(lower(string(mode)),["fixed" "adaptive"])
    error('DRE:DecodeMode','Mode must be fixed or adaptive.');
end
if numel(layout.dataRows) ~= config.payloadSymbolCount || ...
        any(layout.kind(layout.bootstrapRows)~="bootstrap") || ...
        any(layout.kind(layout.dataRows)~="data") || ...
        any(layout.kind(layout.midambleRows)~="midamble")
    error('DRE:PaperFlowLayout','Frame labels and payload dimensions disagree.');
end

position = (0:physicalCount-1).';
observedError = nan(physicalCount,1);
estimatedError = nan(physicalCount,1);
detected = nan(config.payloadSymbolCount,1);
knownPilotUsed = false(physicalCount,1);

% Eq. (18): all initial upchirps are receiver-known symbol zero.
observedError(1) = rawBins(1)-round(rawBins(1)/m)*m;
for row=2:n
    observedError(row) = rawBins(row)+ ...
        round((observedError(row-1)-rawBins(row))/m)*m;
end
knownPilotUsed(1:n) = true;
[fixedSlope,fixedIntercept] = localFit(position(1:n),observedError(1:n));

for row=n+1:physicalCount
    if strcmpi(mode,'adaptive')
        history = row-n:row-1;
        [slope,intercept] = localFit(position(history),observedError(history));
    else
        slope = fixedSlope;
        intercept = fixedIntercept;
    end
    prediction = slope*position(row)+intercept;
    estimatedError(row) = prediction;
    if layout.kind(row)=="midamble"
        % This zero-bin symbol is already known in the common V4 frame.
        symbol = 0;
        knownPilotUsed(row) = true;
    elseif layout.kind(row)=="data"
        % Eq. (21): current decision uses only earlier observations.
        symbol = mod(round(rawBins(row)-prediction),m);
        detected(layout.dataIndex(row)) = symbol;
    else
        error('DRE:PaperFlowLayout','Unexpected physical symbol label.');
    end
    % Eq. (22), or Eq. (18) for a known midamble. FFT bins are cyclic;
    % choose the lift nearest the causal prediction before storing error.
    lifted = rawBins(row)+round((symbol+prediction-rawBins(row))/m)*m;
    observedError(row) = lifted-symbol;
end

result = struct('detectedSymbols',detected, ...
    'estimatedErrorBins',estimatedError, ...
    'observedErrorBins',observedError, ...
    'knownPilotUsed',knownPilotUsed, ...
    'knownMidambleCount',sum(knownPilotUsed(layout.midambleRows)), ...
    'fixedSlopeBinsPerPhysicalSymbol',fixedSlope, ...
    'fixedInterceptBins',fixedIntercept, ...
    'mode',char(lower(string(mode))),'usesPayloadTruth',false);
end

function [slope,intercept] = localFit(x,y)
x = double(x(:)); y = double(y(:));
xMean = mean(x); yMean = mean(y);
denominator = sum((x-xMean).^2);
slope = sum((x-xMean).*(y-yMean))/denominator;
intercept = yMean-slope*xMean;
end
