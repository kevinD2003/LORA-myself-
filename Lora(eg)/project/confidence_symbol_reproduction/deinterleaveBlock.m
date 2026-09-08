function llrCodewords = deinterleaveBlock(llrSymbols)
%DEINTERLEAVEBLOCK Minimal block deinterleaver for the reproduction demo.
%
% Input shape:  (4 + CR)-by-SF
% Output shape: SF-by-(4 + CR)
%
% This is the dimensional transform used by Algorithm 2. Exact LoRa
% diagonal deinterleaving can be substituted here for raw packet data.

arguments
    llrSymbols (:,:) double
end

llrCodewords = llrSymbols.';

end

