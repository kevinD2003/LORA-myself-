function [codedBer,uncodedBer] = ...
        satelliteFig3TheoreticalHammingBerAwgn(sf,snrDb)
%SATELLITEFIG3THEORETICALHAMMINGBERAWGN Coded AWGN BER reference.
%   The exact noncoherent orthogonal-CSS Gray-bit BER is passed through an
%   exhaustive Hamming(7,4) hard-decision decoder enumerator.  Diagonal
%   interleaving places the seven bits of each codeword in independent LoRa
%   symbols, so the enumerator uses seven independent BSC observations.

arguments
    sf (1,1) double {mustBeInteger,mustBePositive}
    snrDb (:,1) double
end

uncodedBer = satelliteFig3TheoreticalBerAwgn(sf,snrDb);
table = localCodeTable();
errorPatterns = false(128,7);
weights = zeros(128,1);
for pattern = 0:127
    errorPatterns(pattern+1,:) = ...
        bitget(uint32(pattern),7:-1:1) ~= 0;
    weights(pattern+1) = sum(errorPatterns(pattern+1,:));
end

codedBer = zeros(size(uncodedBer));
for snrIndex = 1:numel(uncodedBer)
    p = uncodedBer(snrIndex);
    total = 0;
    for word = 1:size(table,1)
        for pattern = 1:size(errorPatterns,1)
            received = xor(table(word,:),errorPatterns(pattern,:));
            score = sum(table == received,2);
            [~,decoded] = max(score);
            dataErrors = sum(table(decoded,1:4) ~= table(word,1:4));
            probability = p^weights(pattern)* ...
                (1-p)^(7-weights(pattern));
            total = total+dataErrors*probability;
        end
    end
    codedBer(snrIndex) = total/(size(table,1)*4);
end
end

function table = localCodeTable()
table = false(16,7);
for value = 0:15
    data = bitget(uint32(value),4:-1:1) ~= 0;
    parity = mod([double(data(1))+double(data(2))+double(data(4)), ...
        double(data(1))+double(data(3))+double(data(4)), ...
        double(data(2))+double(data(3))+double(data(4))],2) ~= 0;
    table(value+1,:) = [data,parity];
end
end
