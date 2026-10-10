function config = dreFullPhyConfig()
%DREFULLPHYCONFIG Frozen assumptions for Figs. 3-4 and Tables V-VI.

config = drePaperConfig();
config.identity = 'dietl-wsa2025-full-phy-v1';
config.crValues = [1 4];
config.payloadBitCount = 256;
config.crcBitCount = 16;
config.paddingBitCount = 16;
config.hammingBlockCount = 6;
config.paddingSymbolCount = 1;
config.fullPhyOverpasses = 3000;
config.calibrationSamplesPerSnr = 5000;
config.calibrationChunkSize = 50;
config.crcPolynomialHex = '1021';
config.crcInitialValue = 0;
config.whiteningPolynomial = 'x^9+x^5+1';
config.codedBerDefinition = ...
    'pre-Hamming coded-bit BER over transmitted packets';
config.crcFilteredCodedBerDefinition = ...
    'sensitivity metric restricted to post-Hamming CRC-success packets';
config.plrDefinition = 'post-Hamming CRC-failure fraction';
config.paperCr1AdaptiveBerPercent = [0.44 0.45 0.58 1.28 4.74].';
config.paperCr1AdaptivePlrPercent = [0.88 0.88 0.95 1.18 7.96].';
config.paperCr1FixedBerPercent = [2.22 2.28 2.48 2.80 6.88].';
config.paperCr1FixedPlrPercent = [0.88 0.88 0.88 1.03 7.52].';
config.paperCr4AdaptiveBerPercent = [0 0.02 0.31 0.96 4.81].';
config.paperCr4AdaptivePlrPercent = [0 0 0.12 0.20 7.89].';
config.paperCr4FixedBerPercent = [3.19 3.28 3.47 4.06 8.02].';
config.paperCr4FixedPlrPercent = [0 0 0 0.20 7.89].';
config.fullPhyAlgorithmVersion = 'empirical-centroid-full-phy-v2-cr1-even-parity';
end
