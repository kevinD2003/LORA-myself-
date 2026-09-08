function symbolCount = loraPayloadSymbolCount( ...
    payloadBits, spreadingFactor, codingRateIndex, ...
    ldroEnabled, crcEnabled, implicitHeader)
%LORAPAYLOADSYMBOLCOUNT Standard LoRa payload-symbol expression.

arguments
    payloadBits (1,1) double {mustBeInteger, mustBeNonnegative}
    spreadingFactor (1,1) double {mustBeInteger, mustBeInRange(spreadingFactor, 5, 12)}
    codingRateIndex (1,1) double {mustBeInteger, mustBeInRange(codingRateIndex, 1, 4)}
    ldroEnabled (1,1) logical
    crcEnabled (1,1) logical
    implicitHeader (1,1) logical
end

payloadBytes = payloadBits/8;
validateattributes(payloadBytes, {'numeric'}, ...
    {'scalar', 'integer', 'nonnegative'});
lowDataRateTerm = double(ldroEnabled);
crcTerm = double(crcEnabled);
headerTerm = double(implicitHeader);
numerator = 8*payloadBytes - 4*spreadingFactor + 28 + ...
    16*crcTerm - 20*headerTerm;
denominator = 4*(spreadingFactor - 2*lowDataRateTerm);
symbolCount = 8 + max(ceil(numerator/denominator)* ...
    (codingRateIndex + 4), 0);
end
