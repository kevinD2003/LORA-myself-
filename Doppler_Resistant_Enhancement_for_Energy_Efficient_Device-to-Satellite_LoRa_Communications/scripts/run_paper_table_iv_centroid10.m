function result = run_paper_table_iv_centroid10()
%RUN_PAPER_TABLE_IV_CENTROID10 Table IV with literal ten-point centroid.

root = dreSetupPaths(false);
config = drePaperConfig();
sourceFiles = { ...
    fullfile(root,'scripts','run_paper_table_iv_centroid10.m'); ...
    fullfile(root,'src','dreEstimatePaperCentroids10.m'); ...
    fullfile(root,'src','dreDecodeLinearRegression.m'); ...
    fullfile(root,'src','dreGeneratePaperPacket.m'); ...
    fullfile(root,'src','drePaperOrbit.m'); ...
    fullfile(root,'src','dreModulateSymbols.m'); ...
    fullfile(root,'src','dreCircularSymbolDistance.m')};
sourceHashes = strings(numel(sourceFiles),2);
for k=1:numel(sourceFiles)
    sourceHashes(k,:) = [string(sourceFiles{k}), ...
        string(localSha256(sourceFiles{k}))];
end
signature = dreConfigurationSignature(struct('config',config, ...
    'sourceHashes',sourceHashes,'centroidPointCount',10));
output = fullfile(root,'results','paper_centroid10_verified');
if ~isfolder(output),mkdir(output);end
matPath = fullfile(output,'table_iv_centroid10.mat');
if isfile(matPath)
    cached = load(matPath,'result');
    if ~strcmp(cached.result.signature,signature)
        error('DRE:PaperCentroid10Signature', ...
            'Existing Table IV result has another source signature.');
    end
    result = cached.result;
    localWriteSidecars(result.table,output);
    return
end

orbit = drePaperOrbit(0,config);
duration = config.packetSymbolCount*config.symbolDurationSec+ ...
    config.packetGapSec;
starts = (-orbit.horizonTimeSec:duration: ...
    (orbit.horizonTimeSec-duration)).';
snrDb = config.snrDb(:);
packetCount = repmat(numel(starts),numel(snrDb),1);
payloadSymbols = packetCount*config.payloadSymbolCount;
adaptiveSerPercent = zeros(size(snrDb));
fixedSerPercent = zeros(size(snrDb));
adaptiveMeanErrorMagnitude = zeros(size(snrDb));
fixedMeanErrorMagnitude = zeros(size(snrDb));
for snrIndex=1:numel(snrDb)
    errors = zeros(1,2);
    magnitudes = zeros(1,2);
    for packetIndex=1:numel(starts)
        seed = config.randomSeed+round((snrDb(snrIndex)+100)*100000)+ ...
            packetIndex;
        packet = dreGeneratePaperPacket( ...
            starts(packetIndex),snrDb(snrIndex),seed,config);
        centroid = dreEstimatePaperCentroids10(packet.rx,config);
        methods = {'adaptive','fixed'};
        for method=1:2
            decoded = dreDecodeLinearRegression(centroid.rawBins, ...
                packet.symbols(1:config.preambleSymbolCount), ...
                config,methods{method});
            mismatch = decoded.detectedSymbols~=packet.payloadSymbols;
            errors(method) = errors(method)+sum(mismatch);
            if any(mismatch)
                distance = dreCircularSymbolDistance( ...
                    decoded.detectedSymbols(mismatch), ...
                    packet.payloadSymbols(mismatch),config.samplesPerSymbol);
                magnitudes(method) = magnitudes(method)+sum(distance);
            end
        end
    end
    adaptiveSerPercent(snrIndex) = 100*errors(1)/payloadSymbols(snrIndex);
    fixedSerPercent(snrIndex) = 100*errors(2)/payloadSymbols(snrIndex);
    adaptiveMeanErrorMagnitude(snrIndex) = magnitudes(1)/max(errors(1),1);
    fixedMeanErrorMagnitude(snrIndex) = magnitudes(2)/max(errors(2),1);
    fprintf('Table IV ten-point SNR %+g: %d packets complete\n', ...
        snrDb(snrIndex),numel(starts));
end
paperAdaptiveSerPercent = config.paperAdaptiveSerPercent(:);
paperFixedSerPercent = config.paperFixedSerPercent(:);
paperAdaptiveMeanErrorMagnitude = config.paperAdaptiveMeanErrorMagnitude(:);
paperFixedMeanErrorMagnitude = config.paperFixedMeanErrorMagnitude(:);
adaptiveSerDeltaPoints = adaptiveSerPercent-paperAdaptiveSerPercent;
fixedSerDeltaPoints = fixedSerPercent-paperFixedSerPercent;
tableOut = table(snrDb,packetCount,payloadSymbols,adaptiveSerPercent, ...
    paperAdaptiveSerPercent,adaptiveSerDeltaPoints,fixedSerPercent, ...
    paperFixedSerPercent,fixedSerDeltaPoints, ...
    adaptiveMeanErrorMagnitude,paperAdaptiveMeanErrorMagnitude, ...
    fixedMeanErrorMagnitude,paperFixedMeanErrorMagnitude);
result = struct('status','COMPLETE','signature',signature, ...
    'config',config,'sourceHashes',sourceHashes,'centroidPointCount',10, ...
    'table',tableOut,'receiverUsesPayloadTruth',false);
save(matPath,'result','-v7.3');
localWriteSidecars(tableOut,output);
end

function localWriteSidecars(t,output)
writetable(t,fullfile(output,'table_iv_centroid10.csv'));
figure('Visible','off','Color','w','Position',[100 100 850 500]);
plot(t.snrDb,t.adaptiveSerPercent,'o-','LineWidth',1.5);hold on;
plot(t.snrDb,t.paperAdaptiveSerPercent,'o--','LineWidth',1.3);
plot(t.snrDb,t.fixedSerPercent,'s-','LineWidth',1.5);
plot(t.snrDb,t.paperFixedSerPercent,'s--','LineWidth',1.3);
grid on;xlabel('SNR (dB)');ylabel('SER (%)');
title('Paper Table IV: literal ten-point centroid');
legend('Adaptive reproduced','Adaptive paper','Fixed reproduced', ...
    'Fixed paper','Location','northwest');
exportgraphics(gcf,fullfile(output,'table_iv_centroid10.png'), ...
    'Resolution',180);
close(gcf);
end

function value=localSha256(path)
file=fopen(path,'rb');
if file<0,error('DRE:SourceMissing','Source file not found: %s',path);end
closer=onCleanup(@()fclose(file));
bytes=fread(file,Inf,'*uint8');
digest=java.security.MessageDigest.getInstance('SHA-256');
digest.update(bytes);
raw=typecast(digest.digest(),'uint8');
value=lower(reshape(dec2hex(raw,2).',1,[]));
end
