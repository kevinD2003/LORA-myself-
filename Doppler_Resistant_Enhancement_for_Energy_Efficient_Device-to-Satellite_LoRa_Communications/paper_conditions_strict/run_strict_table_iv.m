function result = run_strict_table_iv(options)
%RUN_STRICT_TABLE_IV Direct-IQ Table IV under literal Section IV parameters.
arguments
    options.Overpasses (1,1) double {mustBeInteger,mustBePositive}=1
    options.MaximumPacketsPerCall (1,1) double {mustBeInteger,mustBePositive}=1000
end
folder=strictPaperSetup();config=strictPaperConfig();
config.identity='strict-table-iv-B62600-M51-v5';
config.tableIvOverpasses=options.Overpasses;
identity=strictPaperIdentity(config,'run_strict_table_iv.m');
signature=dreConfigurationSignature(identity);
output=fullfile(folder,'results',sprintf('table_iv_v5_O%d',options.Overpasses));
if ~isfolder(output),mkdir(output);end
path=fullfile(output,'table_iv.mat');
if isfile(path)
    cached=load(path,'result');
    if ~strcmp(cached.result.signature,signature)
        error('StrictPaper:CacheSignature','Table IV source/config changed.');
    end
    result=cached.result;
else
    orbit=drePaperOrbit(0,config);
    duration=config.packetSymbolCount*config.symbolDurationSec;
    starts=(-orbit.horizonTimeSec:duration:orbit.horizonTimeSec-duration).';
    count=numel(starts);snr=config.snrDb(:);
    errors=zeros(numel(snr),2);absoluteMagnitude=zeros(size(errors));
    circularMagnitude=zeros(size(errors));
    packetErrors=zeros(count,options.Overpasses,2,numel(snr),'uint16');
    checkpoint=fullfile(output,'checkpoint.mat');completedPackets=0;executed=0;
    if isfile(checkpoint)
        saved=load(checkpoint,'state','savedSignature');
        if ~strcmp(saved.savedSignature,signature)
            error('StrictPaper:CheckpointSignature','Table IV source/config changed.');
        end
        completedPackets=saved.state.completedPackets;errors=saved.state.errors;
        absoluteMagnitude=saved.state.absoluteMagnitude;
        circularMagnitude=saved.state.circularMagnitude;packetErrors=saved.state.packetErrors;
    end
    for si=1:numel(snr)
        for packetIndex=1:count
            globalIndex=(si-1)*count+packetIndex;
            if globalIndex<=completedPackets,continue;end
            data=zeros(config.payloadSymbolCount,options.Overpasses);
            noiseSeed=zeros(1,options.Overpasses);
            for pass=1:options.Overpasses
                stream=RandStream('mt19937ar','Seed',config.randomSeed+ ...
                    1000000+si*10000+packetIndex+(pass-1)*10000000);
                data(:,pass)=randi(stream,[0 config.samplesPerSymbol-1],config.payloadSymbolCount,1);
                noiseSeed(pass)=config.randomSeed+2000000+si*10000+packetIndex+(pass-1)*10000000;
            end
            symbols=[zeros(config.preambleSymbolCount,options.Overpasses);data];
            raw=strictPaperRawBatch(symbols,starts(packetIndex),snr(si),noiseSeed,config);
            modes={'adaptive','fixed'};
            for method=1:2
                decoded=dreDecodeLinearRegressionBatch(raw, ...
                    config.preambleSymbolCount,config.samplesPerSymbol,modes{method});
                decisions=decoded.detectedSymbols;
                mismatch=decisions~=data;
                packetErrors(packetIndex,:,method,si)=uint16(sum(mismatch,1));
                errors(si,method)=errors(si,method)+sum(mismatch,'all');
                absoluteMagnitude(si,method)=absoluteMagnitude(si,method)+ ...
                    sum(abs(decisions(mismatch)-data(mismatch)));
                circularMagnitude(si,method)=circularMagnitude(si,method)+ ...
                    sum(dreCircularSymbolDistance(decisions(mismatch), ...
                    data(mismatch),config.samplesPerSymbol));
            end
            completedPackets=globalIndex;executed=executed+1;
            if mod(globalIndex,10)==0 || packetIndex==count || ...
                    executed>=options.MaximumPacketsPerCall
                state=struct('completedPackets',completedPackets,'errors',errors, ...
                    'absoluteMagnitude',absoluteMagnitude,'circularMagnitude',circularMagnitude, ...
                    'packetErrors',packetErrors);savedSignature=signature; %#ok<NASGU>
                temporary=[checkpoint '.tmp'];save(temporary,'state','savedSignature','-v7.3');
                movefile(temporary,checkpoint,'f');
            end
            if executed>=options.MaximumPacketsPerCall && completedPackets<count*numel(snr)
                result=struct('status','CHECKPOINTED','signature',signature, ...
                    'completedPackets',completedPackets,'totalPacketPositions',count*numel(snr));
                fprintf('Strict Table IV checkpointed: %d/%d positions\n',completedPackets,count*numel(snr));
                return
            end
        end
        fprintf('Strict Table IV SNR %+g: %d packets x %d overpasses\n',snr(si),count,options.Overpasses);
    end
    denominator=count*config.payloadSymbolCount*options.Overpasses;
    rates=100*errors/denominator;
    absoluteMeans=absoluteMagnitude./max(errors,1);
    circularMeans=circularMagnitude./max(errors,1);
    packetCount=count*options.Overpasses*ones(numel(snr),1);
    symbolCount=denominator*ones(numel(snr),1);
    summary=table(snr,packetCount,symbolCount,rates(:,1), ...
        config.paperAdaptiveSerPercent,rates(:,1)-config.paperAdaptiveSerPercent, ...
        rates(:,2),config.paperFixedSerPercent,rates(:,2)-config.paperFixedSerPercent, ...
        absoluteMeans(:,1),config.paperAdaptiveMeanErrorMagnitude, ...
        absoluteMeans(:,2),config.paperFixedMeanErrorMagnitude, ...
        circularMeans(:,1),circularMeans(:,2), ...
        'VariableNames',{'snrDb','packetCount','symbolCount','adaptiveSerPercent', ...
        'paperAdaptiveSerPercent','adaptiveSerDeltaPoints','fixedSerPercent', ...
        'paperFixedSerPercent','fixedSerDeltaPoints','adaptiveAbsoluteMeanSE', ...
        'paperAdaptiveMeanSE','fixedAbsoluteMeanSE','paperFixedMeanSE', ...
        'adaptiveCircularMeanSE','fixedCircularMeanSE'});
    result=struct('status','COMPLETE','signature',signature,'identity',identity, ...
        'config',config,'table',summary,'errors',errors, ...
        'packetStartTimesSec',starts,'receiverUsesPayloadTruth',false, ...
        'directSampleLevelIQ',true,'centroidPointCount',10, ...
        'packetErrors',packetErrors,'overpasses',options.Overpasses);
    save(path,'result','-v7.3');
end
writetable(result.table,fullfile(output,'table_iv.csv'));
fig=figure('Visible','off','Color','w','Position',[100 100 1050 610]);
t=result.table;
plot(t.snrDb,t.adaptiveSerPercent,'o-','LineWidth',1.6);hold on;
plot(t.snrDb,t.paperAdaptiveSerPercent,'o--','LineWidth',1.4);
plot(t.snrDb,t.fixedSerPercent,'s-','LineWidth',1.6);
plot(t.snrDb,t.paperFixedSerPercent,'s--','LineWidth',1.4);
grid on;xlabel('SNR (dB)');ylabel('SER (%)');
title('Paper Table IV: 62.6 kHz, M=51, direct IQ, 10-point centroid');
legend('Adaptive reproduced','Adaptive paper','Fixed reproduced', ...
    'Fixed paper','Location','northwest');
exportgraphics(fig,fullfile(output,'table_iv.png'),'Resolution',200);close(fig);
end
