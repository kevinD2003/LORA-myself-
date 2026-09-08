function result = satelliteFig3HuangPrecCpMatchedDecode( ...
        rxSymbols,config,knownWaveformBins)
%SATELLITEFIG3HUANGPRECCPMATCHEDDECODE Fair Huang-PREC comparison arm.
%   The CFO front end follows Huang Peng's PREC equations (4-1)--(4-7).
%   Per-upchirp FFT powers are accumulated before the eta/peak search so
%   the eight-preamble estimator remains valid for a physical waveform
%   whose CFO phase is continuous across LoRa-symbol boundaries.  The
%   estimated CFO is frozen over the payload, as in the thesis receiver.
%
%   For a decoder-matched comparison with Stage55 SenLoRa, both hard
%   Hamming and the project's common ML-soft Hamming outputs are returned.
%   No payload decision is fed back to the PREC CFO estimate.

static = satelliteFig3HuangPrecStaticCpDecode( ...
    rxSymbols,config,knownWaveformBins);
soft = satelliteFig3SenLoRaConfidence( ...
    static.tracker.compensatedSymbols,config, ...
    AmendLlrMix=config.amendLlrMix);

result = static;
result.hardDecodedDataBits = static.decodedDataBits;
result.softDecodedDataBits = soft.mlDecodedDataBits;
result.decodedDataBits = soft.mlDecodedDataBits;
result.soft = soft;
result.finalDecodeMetric = ...
    'ML soft Hamming(7,4) from the same raw-bit LLR engine as Stage55';
result.comparisonRole = ...
    'Huang-PREC CFO front end with decoder-matched Stage55 output';
result.algorithmProvenance = [ ...
    'Huang thesis (4-1)--(4-7); continuous-phase power combining; ' ...
    'frozen payload CFO; common ML-soft Hamming output'];
end
