function decoded = fuxianCommonPayloadDecode( ...
    compensatedPhysical,hardPhysical,layout,config)
%FUXIANCOMMONPAYLOADDECODE Apply the frozen common hard/soft decoder.

compact = compensatedPhysical(layout.compactRows,:);
soft = satelliteFig3SenLoRaConfidence( ...
    compact,config,AmendLlrMix=config.amendLlrMix);
hardDataBins = hardPhysical(layout.dataRows);
hardDataBits = satelliteFig3HardPayloadBits(hardDataBins,config);

decoded.compactCompensatedSymbols = compact;
decoded.hardDataBins = hardDataBins;
decoded.hardDecodedDataBits = hardDataBits;
decoded.softDecodedDataBits = soft.mlDecodedDataBits;
decoded.decodedDataBits = soft.mlDecodedDataBits;
decoded.soft = soft;
decoded.finalDecodeMetric = ...
    'common Stage55 ML-soft Hamming(7,4)';
end
