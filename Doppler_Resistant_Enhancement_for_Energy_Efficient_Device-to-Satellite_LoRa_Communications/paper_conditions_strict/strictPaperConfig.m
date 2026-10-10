function config = strictPaperConfig()
%STRICTPAPERCONFIG Literal Section IV conditions and explicit missing details.
config = dreFullPhyConfig();
config.identity = 'dietl-wsa2025-direct-iq-paper-conditions-v5';
config.bandwidthHz = 62.6e3;
config.reportedBandwidthHz = 62.6e3;
config.sampleRateHz = config.bandwidthHz;
config.symbolDurationSec = config.samplesPerSymbol/config.sampleRateHz;
config.fftBinSpacingHz = config.bandwidthHz/config.samplesPerSymbol;
config.zeroPaddingFactor = 4;
config.centroidSampleCount = 10;
config.phaseModel = 'paper-equation-15-product';
config.codedBerDefinition = 'pre-Hamming coded-bit BER on CRC-success packets';
config.allPacketBerDefinition = 'diagnostic pre-Hamming coded-bit BER on all packets';
config.meanErrorDefinition = 'mean absolute decoded-symbol error on erroneous symbols';
config.fullPhyAlgorithmVersion = 'direct-iq-ten-point-causal-ols-crc-filtered-v5';
config.nativeThreads=2;
config.numericPrecision='double';
config.sampleEngine='native direct-IQ, MATLAB per-packet MT19937 AWGN';
config.assumptions = struct('preambleSymbolCount',8, ...
    'hannDefinition','periodic','centroidOffsets',(-4:5), ...
    'centroidWeights','FFT magnitude', ...
    'fftAlphabet','cyclic nearest-bin quantization and causal unwrapping', ...
    'dopplerPhase','literal Eq. (15), carrier-frequency term of Eq. (14)', ...
    'fullPhyPayloadBytes',32,'fullPhyCodingBlocks',6, ...
    'fullPhyPaddingBits',16,'fullPhyTrailingSymbols',1, ...
    'passRange','geometric horizon to geometric horizon; back-to-back packets');
end
