function estimate = v4PaperNativePointEstimate(downchirpSamples,config)
%V4PAPERNATIVEPOINTESTIMATE Integer FFT-bin Point estimator only.
up = v4ModulateSymbol(0,config);
spectrum = fft(downchirpSamples(:).'.*up);
[~,index] = max(abs(spectrum).^2);
signedBin = index-1;
if signedBin >= config.samplesPerSymbol/2, signedBin = signedBin-config.samplesPerSymbol; end
estimate = struct('offsetBins',signedBin,'offsetHz',signedBin*config.fftBinSpacingHz, ...
    'resolution','integer-fft-bin','fftIndex',index-1,'usesTruth',false);
end
