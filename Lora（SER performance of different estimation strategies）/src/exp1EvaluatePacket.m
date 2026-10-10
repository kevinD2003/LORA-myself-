function packet = exp1EvaluatePacket(frame,config,methodNames)
%EXP1EVALUATEPACKET Run frozen receivers on one shared paired frame.

c = config.parent;
parameters = v4LoadMethodAlignedR3ParametersV1();
common = v4CommonBootstrap(frame.observation.rxPhysical(1:8,:),c, ...
    SearchStepBins=parameters.searchStepBins);
methodCount = numel(methodNames);
nData = c.payloadSymbolCount;
packet = struct();
packet.methodNames = methodNames;
packet.symbolErrors = zeros(1,methodCount,'uint16');
packet.hardBitErrors = zeros(1,methodCount,'uint16');
packet.mlBitErrors = zeros(1,methodCount,'uint16');
packet.packetError = false(1,methodCount);
packet.hardPacketError = false(1,methodCount);
packet.symbolErrorMask = false(methodCount,nData);
packet.cfoResidualBins = nan(methodCount,nData,'single');
packet.cfoRmseBins = nan(1,methodCount);
packet.cfoRmseHz = nan(1,methodCount);
packet.rateRmseBinsPerSec = nan(1,methodCount);
packet.candidateVp = zeros(1,methodCount,'uint16');
packet.acceptedVp = zeros(1,methodCount,'uint16');
packet.falseVp = zeros(1,methodCount,'uint16');
packet.failed = false(1,methodCount);
packet.failureMessage = repmat({''},1,methodCount);
packet.algorithmVersion = repmat({''},1,methodCount);
packet.receiverMode = repmat({''},1,methodCount);

for method = 1:methodCount
    try
        name = methodNames{method};
        switch name
            case 'Huang'
                receiver = v4HuangPrecUnifiedDecodeV9(frame.observation,c);
            case 'Paper'
                receiver = v4PaperMidamblePointUnifiedV6( ...
                    frame.observation,common,c);
            case 'Stage55'
                receiver = exp1Stage55Decode(frame.observation,common,config,true);
            case 'Stage55-VP-off'
                receiver = exp1Stage55Decode(frame.observation,common,config,false);
            case 'Ideal'
                receiver = exp1IdealDecode(frame,config);
            otherwise
                error('EXP1:Method','Unknown receiver method %s.',name);
        end
        symbolMask = receiver.detectedPhysicalBins(:) ~= ...
            frame.truth.payloadPhysicalBins(:);
        hardMask = receiver.hardDecodedDataBits(:) ~= frame.truth.dataBits(:);
        mlMask = receiver.softDecodedDataBits(:) ~= frame.truth.dataBits(:);
        packet.symbolErrorMask(method,:) = symbolMask.';
        packet.symbolErrors(method) = uint16(sum(symbolMask));
        packet.hardBitErrors(method) = uint16(sum(hardMask));
        packet.mlBitErrors(method) = uint16(sum(mlMask));
        packet.packetError(method) = any(symbolMask);
        packet.hardPacketError(method) = any(hardMask);
        if isfield(receiver,'estimatedCfoBins')
            residual = receiver.estimatedCfoBins(:)-frame.truth.dataCfoBins(:);
            packet.cfoResidualBins(method,:) = single(residual).';
            finite = isfinite(residual);
            if any(finite)
                packet.cfoRmseBins(method) = sqrt(mean(residual(finite).^2));
                packet.cfoRmseHz(method) = ...
                    packet.cfoRmseBins(method)*c.fftBinSpacingHz;
            end
        end
        if isfield(receiver,'estimatedRateBinsPerSec')
            rateResidual = receiver.estimatedRateBinsPerSec(:)- ...
                frame.truth.dataRateBinsPerSec(:);
            finite = isfinite(rateResidual);
            if any(finite)
                packet.rateRmseBinsPerSec(method) = ...
                    sqrt(mean(rateResidual(finite).^2));
            end
        end
        if isfield(receiver,'virtualPilotAccepted')
            accepted = logical(receiver.virtualPilotAccepted(:));
            packet.acceptedVp(method) = uint16(sum(accepted));
            if any(accepted) && isfield(receiver,'tracker') && ...
                    isfield(receiver.tracker,'hardPhysicalBins')
                falseMask = accepted & (receiver.tracker.hardPhysicalBins(:) ~= ...
                    frame.truth.payloadPhysicalBins(:));
                packet.falseVp(method) = uint16(sum(falseMask));
            end
        end
        packet.candidateVp(method) = uint16(localCandidateCount(receiver,nData));
        if isfield(receiver,'algorithmVersion')
            packet.algorithmVersion{method} = receiver.algorithmVersion;
        else
            packet.algorithmVersion{method} = name;
        end
        packet.receiverMode{method} = localMode(receiver);
    catch exception
        packet.failed(method) = true;
        packet.failureMessage{method} = sprintf('%s: %s', ...
            exception.identifier,exception.message);
        packet.symbolErrors(method) = uint16(c.payloadSymbolCount);
        packet.hardBitErrors(method) = uint16(c.informationBitCount);
        packet.mlBitErrors(method) = uint16(c.informationBitCount);
        packet.packetError(method) = true;
        packet.hardPacketError(method) = true;
        packet.symbolErrorMask(method,:) = true;
        packet.algorithmVersion{method} = 'FAILED';
        packet.receiverMode{method} = 'failed-counted-as-errors';
    end
end
end

function count = localCandidateCount(receiver,nData)
count = 0;
if isfield(receiver,'iterationHistory') && ~isempty(receiver.iterationHistory)
    candidate = false(nData,1);
    for iteration = 1:numel(receiver.iterationHistory)
        if isfield(receiver.iterationHistory(iteration),'proposedMask')
            candidate = candidate | ...
                logical(receiver.iterationHistory(iteration).proposedMask(:));
        end
    end
    count = sum(candidate);
end
end

function value = localMode(receiver)
fields = {'huangRegime','paperRegime','stageRegime'};
value = '';
for index = 1:numel(fields)
    if isfield(receiver,fields{index})
        value = receiver.(fields{index});
        return
    end
end
if isfield(receiver,'referenceOnly') && receiver.referenceOnly
    value = 'ideal-reference';
end
end
