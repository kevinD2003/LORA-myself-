function rx = strictPaperGenerateIQ(symbols,startTimeSec,snrDb,seeds,config)
%STRICTPAPERGENERATEIQ Unit-power CSS, literal Eq. (15), sample-level AWGN.
% Each column is one packet. Output rows are packet-major symbol-major.
% Independent per-packet noise seeds make batching and restarts identical.
[symbolCount,replicates]=size(symbols);
m=config.samplesPerSymbol;
if numel(seeds)~=replicates || any(symbols(:)<0 | symbols(:)>=m | ...
        symbols(:)~=floor(symbols(:))) || ~isfinite(startTimeSec) || ...
        isnan(snrDb) || snrDb==-Inf
    error('StrictPaper:IQShape','Invalid symbols, noise seeds, or SNR.');
end
persistent previousKey previousModel template
key=[startTimeSec symbolCount m config.sampleRateHz config.orbitHeightM ...
    config.carrierFrequencyHz config.gravityMps2 config.earthRadiusM ...
    config.speedOfLightMps];
if isempty(previousKey) || ~isequal(previousKey,key) || ...
        ~strcmp(previousModel,config.phaseModel)
    times=startTimeSec+(0:symbolCount*m-1).'/config.sampleRateHz;
    orbit=drePaperOrbit(times,config);
    switch config.phaseModel
        case 'paper-equation-15-product'
            phase=2*pi*orbit.dopplerHz(:).*times;
        case 'integrated-instantaneous-doppler'
            frequency=orbit.dopplerHz(:);
            phase=[0;cumsum(pi/config.sampleRateHz* ...
                (frequency(1:end-1)+frequency(2:end)))];
        otherwise
            error('StrictPaper:PhaseModel','Unknown Doppler phase model.');
    end
    up=dreModulateSymbols(0,config);
    template=exp(1i*reshape(phase,m,symbolCount).').*up;
    previousKey=key;previousModel=config.phaseModel;
end
n=0:m-1;
rx=exp(1i*2*pi*(double(symbols(:))*n)/m).*repmat(template,replicates,1);
if snrDb~=Inf
    noiseScale=sqrt(10^(-snrDb/10)/2);
    for replicate=1:replicates
        stream=RandStream('mt19937ar','Seed',seeds(replicate));
        rows=(replicate-1)*symbolCount+(1:symbolCount);
        rx(rows,:)=rx(rows,:)+noiseScale*(randn(stream,symbolCount,m)+ ...
            1i*randn(stream,symbolCount,m));
    end
end
end
