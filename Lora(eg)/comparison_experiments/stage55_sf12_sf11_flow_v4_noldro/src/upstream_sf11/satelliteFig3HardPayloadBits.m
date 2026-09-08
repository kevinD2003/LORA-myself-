function dataBits = satelliteFig3HardPayloadBits(waveformBins,config)
%SATELLITEFIG3HARDPAYLOADBITS Hard Hamming decode for the no-compensation arm.
blockLength = 4+config.cr; blockCount = numel(waveformBins)/blockLength;
dataBits = zeros(config.sf,4,blockCount);
table = localTable();
for block = 1:blockCount
    rows = (block-1)*blockLength+(1:blockLength);
    gray = satelliteFig3GrayEncode(uint32(waveformBins(rows)));
    diagonal = false(config.sf,blockLength);
    for col = 1:blockLength
        for bit = 1:config.sf, diagonal(bit,col) = bitget(gray(col),bit) ~= 0; end
    end
    code = false(config.sf,blockLength);
    for col = 1:blockLength
        for bit = 1:config.sf
            code(mod(bit+col-2,config.sf)+1,col) = diagonal(bit,col);
        end
    end
    for row = 1:config.sf
        scores = sum(table == code(row,:),2);
        [~,best] = max(scores); dataBits(row,:,block) = table(best,1:4);
    end
end
end

function table = localTable()
table = false(16,7);
for value = 0:15
    d = bitget(uint32(value),4:-1:1) ~= 0;
    p = mod([double(d(1))+double(d(2))+double(d(4)), ...
        double(d(1))+double(d(3))+double(d(4)), ...
        double(d(2))+double(d(3))+double(d(4))],2) ~= 0;
    table(value+1,:) = [d,p];
end
end
