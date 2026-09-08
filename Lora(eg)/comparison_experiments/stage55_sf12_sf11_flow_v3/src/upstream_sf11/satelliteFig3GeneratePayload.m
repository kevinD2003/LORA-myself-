function payload = satelliteFig3GeneratePayload(config, seed)
%SATELLITEFIG3GENERATEPAYLOAD Make coded, diagonally-interleaved CSS payload.
%   Each block holds SF systematic Hamming(7,4) codewords and produces
%   4+CR LoRa symbols.  The matching soft decoder will use this exact
%   ordering in the next implementation stage.

arguments
    config (1,1) struct
    seed (1,1) double = 20260804
end

codewordLength = 4 + config.cr;
if codewordLength ~= 7 || mod(config.payloadSymbolCount, codewordLength) ~= 0
    error('SatelliteFig3:UnsupportedCoding', ...
        'Stage 1 expects CR=3 and a whole number of 7-symbol blocks.');
end
blockCount = config.payloadSymbolCount/codewordLength;
stream = RandStream('mt19937ar','Seed',seed);
dataBits = randi(stream,[0 1],config.sf,4,blockCount);
symbolBins = zeros(config.payloadSymbolCount,1);
codedBits = zeros(config.sf,codewordLength,blockCount);
for block = 1:blockCount
    d = dataBits(:,:,block);
    parity = mod([d(:,1)+d(:,2)+d(:,4), ...
        d(:,1)+d(:,3)+d(:,4), d(:,2)+d(:,3)+d(:,4)], 2);
    code = [d, parity];
    codedBits(:,:,block) = code;
    index = (block-1)*codewordLength + (1:codewordLength);
    % Interleaver output carries Gray-label bits.  For this project's
    % discrete up-chirp convention, the transmitted waveform label equals
    % the raw MATLAB FFT bin after dechirping.
    grayLabels = satelliteFig3DiagonalInterleave(code);
    rawFftBins = satelliteFig3GrayDecode(grayLabels);
    symbolBins(index) = double(rawFftBins);
end
payload = struct( ...
    'symbolBins', symbolBins, 'dataBits', dataBits, ...
    'codedBits', codedBits, 'blockCount', blockCount, ...
    'bitsPerBlock', config.sf*4, 'codewordLength', codewordLength);
end
