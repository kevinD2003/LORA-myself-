function result = run_strict_full_phy(options)
%RUN_STRICT_FULL_PHY Direct-IQ Figs. 3/4 and Tables V/VI, exact cache reuse.
% Default is the paper's 3000 overpasses. Smaller runs are explicitly tagged
% VALIDATION_COMPLETE and cannot be mistaken for the formal ensemble.
arguments
    options.Overpasses (1,1) double {mustBeInteger,mustBePositive} = 3000
    options.BatchOverpasses (1,1) double {mustBeInteger,mustBePositive} = 32
    options.MaximumPackets (1,1) double {mustBePositive} = Inf
    options.MaximumBatchesPerCall (1,1) double {mustBePositive} = Inf
    options.SnrDb (:,1) double = [0;-5;-10;-15;-20]
    options.ConditionIndices (:,1) double = []
end
folder=strictPaperSetup();config=strictPaperConfig();
if options.Overpasses>10000 || numel(unique(options.SnrDb))~=numel(options.SnrDb) || ...
        ~all(ismember(options.SnrDb,[0;-5;-10;-15;-20])) || ...
        isempty(options.SnrDb) || ...
        (isfinite(options.MaximumPackets) && ...
        options.MaximumPackets~=floor(options.MaximumPackets))
    error('StrictPaper:Conditions','Use distinct paper SNRs and at most 10000 passes.');
end
config.identity='strict-full-phy-direct-iq-B62600-v5';
config.fullPhyOverpasses=options.Overpasses;
config.maximumPackets=options.MaximumPackets;
config.snrDb=options.SnrDb;
identity=strictPaperIdentity(config,'run_strict_full_phy.m');
signature=dreConfigurationSignature(identity);
packetTag='all';
if isfinite(options.MaximumPackets),packetTag=sprintf('%d',options.MaximumPackets);end
snrTag=strjoin(cellstr(string(options.SnrDb.')),'_');
output=fullfile(folder,'results',sprintf('full_phy_v5_O%d_P%s_S%s', ...
    options.Overpasses,packetTag,snrTag));
if ~isfolder(output),mkdir(output);end
resultPath=fullfile(output,'full_phy.mat');
if isfile(resultPath)
    cached=load(resultPath,'result');
    if ~strcmp(cached.result.signature,signature)
        error('StrictPaper:CacheSignature','Full-PHY source/config changed.');
    end
    result=cached.result;
    localArtifacts(result,output);
    return
end
conditions=cell(2*numel(options.SnrDb),1);conditionIndex=0;usedBatches=0;
if any(options.ConditionIndices~=floor(options.ConditionIndices)) || ...
        any(options.ConditionIndices<1 | options.ConditionIndices>numel(conditions)) || ...
        numel(unique(options.ConditionIndices))~=numel(options.ConditionIndices)
    error('StrictPaper:ConditionIndices','Invalid independent worker cell selection.');
end
for cr=[1 4]
    for si=1:numel(options.SnrDb)
        conditionIndex=conditionIndex+1;
        if ~isempty(options.ConditionIndices) && ...
                ~ismember(conditionIndex,options.ConditionIndices)
            conditions{conditionIndex}=struct('status','NOT_REQUESTED');continue
        end
        remaining=options.MaximumBatchesPerCall-usedBatches;
        [conditions{conditionIndex},executed]=localRunCell(cr, ...
            options.SnrDb(si),conditionIndex,config,identity,signature, ...
            options.BatchOverpasses,remaining,output);
        usedBatches=usedBatches+executed;
        if ~strcmp(conditions{conditionIndex}.status,'COMPLETE')
            result=struct('status','CHECKPOINTED','signature',signature, ...
                'outputDirectory',output,'completedConditions',conditionIndex-1);
            fprintf('Strict full PHY checkpointed; resume with the same options.\n');
            return
        end
    end
end
if ~isempty(options.ConditionIndices)
    result=struct('status','WORKER_COMPLETE','signature',signature, ...
        'outputDirectory',output,'conditionIndices',options.ConditionIndices);
    fprintf('Strict worker complete: conditions %s\n',mat2str(options.ConditionIndices.'));
    return
end
conditions=vertcat(conditions{:});
isFormal=options.Overpasses==3000 && isinf(options.MaximumPackets) && ...
    isequal(options.SnrDb,[0;-5;-10;-15;-20]);
status='VALIDATION_COMPLETE';if isFormal,status='COMPLETE';end
summary=localSummary(conditions,config);
result=struct('status',status,'signature',signature,'identity',identity, ...
    'config',config,'conditions',conditions,'table',summary, ...
    'directSampleLevelIQ',true,'centroidPointCount',10, ...
    'receiverUsesPayloadTruth',false,'formal3000Overpasses',isFormal);
save(resultPath,'result','-v7.3');
localArtifacts(result,output);
end

function [condition,executed]=localRunCell(cr,snrDb,conditionIndex,c, ...
        identity,parentSignature,batchSize,maximumBatches,output)
dataCount=c.hammingBlockCount*(4+cr);
symbolCount=c.preambleSymbolCount+dataCount+c.paddingSymbolCount;
duration=symbolCount*c.symbolDurationSec;
orbit=drePaperOrbit(0,c);
starts=(-orbit.horizonTimeSec:duration:orbit.horizonTimeSec-duration).';
allPackets=numel(starts);
if isfinite(c.maximumPackets) && numel(starts)>c.maximumPackets
    starts=starts(unique(round(linspace(1,numel(starts),c.maximumPackets))));
end
packetCount=numel(starts);
% Batch size is checkpoint identity, not a statistical parameter.
cellSignature=dreConfigurationSignature(struct('parent',parentSignature, ...
    'cr',cr,'snrDb',snrDb,'batchSize',batchSize,'packetStarts',starts));
cellFolder=fullfile(output,sprintf('CR%d_SNR%+d',cr,snrDb));
if ~isfolder(cellFolder),mkdir(cellFolder);end
cellPath=fullfile(cellFolder,'cell.mat');checkpoint=fullfile(cellFolder,'checkpoint.mat');
executed=0;
if isfile(cellPath)
    cached=load(cellPath,'condition');
    if ~strcmp(cached.condition.signature,cellSignature)
        error('StrictPaper:CellSignature','Cell source/config/batching changed.');
    end
    condition=cached.condition;return
end
batchesPerPacket=ceil(c.fullPhyOverpasses/batchSize);
totalBatches=packetCount*batchesPerPacket;
if isfile(checkpoint)
    saved=load(checkpoint,'state','savedSignature');
    if ~strcmp(saved.savedSignature,cellSignature)
        error('StrictPaper:CheckpointSignature','Checkpoint source/config changed.');
    end
    state=saved.state;
else
    fields={'codedErrorsAccepted','codedBitsAccepted','codedErrorsAll', ...
        'codedBitsAll','payloadErrorsAccepted','payloadBitsAccepted','packetLosses'};
    state=struct('completedBatches',0,'processedPasses',zeros(packetCount,1));
    state.passCounts=struct();
    for field=fields
        state.(field{1})=zeros(packetCount,2);
        state.passCounts.(field{1})=zeros(c.fullPhyOverpasses,2);
    end
end
payloadPacketIndex=0;payload=[];
for batch=state.completedBatches+1:totalBatches
    if executed>=maximumBatches,break;end
    packetIndex=floor((batch-1)/batchesPerPacket)+1;
    withinPacket=mod(batch-1,batchesPerPacket)+1;
    passIds=(withinPacket-1)*batchSize+1:min(withinPacket*batchSize,c.fullPhyOverpasses);
    if payloadPacketIndex~=packetIndex
        payloadSeed=c.randomSeed+1000000000+conditionIndex*100000+packetIndex;
        stream=RandStream('mt19937ar','Seed',payloadSeed);
        payload=dreGenerateFullPhyPayload(c.fullPhyOverpasses,cr,c,stream);
        payloadPacketIndex=packetIndex;
    end
    current=struct('payloadBits',payload.payloadBits(:,passIds), ...
        'codedBits',payload.codedBits(:,:,:,passIds), ...
        'logicalBins',payload.logicalBins(:,passIds));
    symbols=[zeros(c.preambleSymbolCount,numel(passIds)); ...
        current.logicalBins;zeros(c.paddingSymbolCount,numel(passIds))];
    noiseSeeds=c.randomSeed+2000000000+conditionIndex*5000000+ ...
        packetIndex*10000+passIds;
    raw=strictPaperRawBatch(symbols,starts(packetIndex),snrDb,noiseSeeds,c);
    modes={'adaptive','fixed'};
    for method=1:2
        receiver=dreDecodeLinearRegressionBatch(raw, ...
            c.preambleSymbolCount,c.samplesPerSymbol,modes{method});
        metrics=strictPaperScorePayload(receiver.detectedSymbols(1:dataCount,:), ...
            current,cr,c);
        names={'codedErrorsAccepted','codedBitsAccepted','codedErrorsAll', ...
            'codedBitsAll','payloadErrorsAccepted','payloadBitsAccepted','packetLosses'};
        for name=names
            state.(name{1})(packetIndex,method)= ...
                state.(name{1})(packetIndex,method)+metrics.(name{1});
            perPacketName=['perPacket' upper(name{1}(1)) name{1}(2:end)];
            state.passCounts.(name{1})(passIds,method)= ...
                state.passCounts.(name{1})(passIds,method)+ ...
                metrics.(perPacketName)(:);
        end
    end
    state.processedPasses(packetIndex)=state.processedPasses(packetIndex)+numel(passIds);
    state.completedBatches=batch;executed=executed+1;
    if mod(batch,10)==0 || batch==totalBatches || executed>=maximumBatches
        savedSignature=cellSignature; %#ok<NASGU>
        tempPath=[checkpoint '.tmp'];save(tempPath,'state','savedSignature','-v7.3');
        movefile(tempPath,checkpoint,'f');
        fprintf('Strict IQ CR%d SNR %+g: %d/%d batches (%d passes/position)\n', ...
            cr,snrDb,batch,totalBatches,c.fullPhyOverpasses);
        localJson(fullfile(cellFolder,'progress.json'),struct( ...
            'completedBatches',batch,'totalBatches',totalBatches, ...
            'packetIndex',packetIndex,'packetCount',packetCount, ...
            'processedPackets',sum(state.processedPasses), ...
            'totalPackets',packetCount*c.fullPhyOverpasses, ...
            'signature',cellSignature));
    end
end
if state.completedBatches<totalBatches
    condition=struct('status','CHECKPOINTED');return
end
if any(state.processedPasses~=c.fullPhyOverpasses)
    error('StrictPaper:PassCount','An orbit position has an incomplete pass count.');
end
primary=localRate(sum(state.codedErrorsAccepted,1),sum(state.codedBitsAccepted,1));
allBer=localRate(sum(state.codedErrorsAll,1),sum(state.codedBitsAll,1));
payloadBer=localRate(sum(state.payloadErrorsAccepted,1),sum(state.payloadBitsAccepted,1));
plr=sum(state.packetLosses,1)/(packetCount*c.fullPhyOverpasses);
center=starts+duration/2;trajectory=drePaperOrbit(center,c);
condition=struct('status','COMPLETE','signature',cellSignature, ...
    'cr',cr,'snrDb',snrDb,'overpasses',c.fullPhyOverpasses, ...
    'packetCount',packetCount,'fullOverpassPacketCount',allPackets, ...
    'packetSymbolCount',symbolCount,'packetStartTimesSec',starts, ...
    'codedBer',primary,'allPacketCodedBer',allBer,'payloadBer',payloadBer, ...
    'plr',plr,'rawCounts',state,'sourceHashes',identity.sourceHashes, ...
    'trajectoryBer',localRate(state.codedErrorsAccepted,state.codedBitsAccepted), ...
    'trajectoryAllPacketBer',localRate(state.codedErrorsAll,state.codedBitsAll), ...
    'trajectoryPlr',state.packetLosses/c.fullPhyOverpasses, ...
    'dopplerHz',trajectory.dopplerHz,'directSampleLevelIQ',true);
temporary=[cellPath '.tmp'];save(temporary,'condition','-v7.3');movefile(temporary,cellPath,'f');
end

function localJson(path,data)
temporary=[path '.tmp'];file=fopen(temporary,'w','n','UTF-8');
closer=onCleanup(@()fclose(file));fprintf(file,'%s\n',jsonencode(data));clear closer
movefile(temporary,path,'f');
end

function value=localRate(numerator,denominator)
value=nan(size(numerator));valid=denominator>0;
value(valid)=numerator(valid)./denominator(valid);
end

function summary=localSummary(conditions,c)
count=numel(conditions);cr=zeros(count,1);snrDb=zeros(count,1);
packetCount=zeros(count,1);overpasses=zeros(count,1);
adaptiveBerPercent=nan(count,1);fixedBerPercent=nan(count,1);
adaptiveAllPacketBerPercent=zeros(count,1);fixedAllPacketBerPercent=zeros(count,1);
adaptivePlrPercent=zeros(count,1);fixedPlrPercent=zeros(count,1);
paperAdaptiveBerPercent=zeros(count,1);paperFixedBerPercent=zeros(count,1);
paperAdaptivePlrPercent=zeros(count,1);paperFixedPlrPercent=zeros(count,1);
for row=1:count
    cellResult=conditions(row);cr(row)=cellResult.cr;snrDb(row)=cellResult.snrDb;
    packetCount(row)=cellResult.packetCount;overpasses(row)=cellResult.overpasses;
    adaptiveBerPercent(row)=100*cellResult.codedBer(1);
    fixedBerPercent(row)=100*cellResult.codedBer(2);
    adaptiveAllPacketBerPercent(row)=100*cellResult.allPacketCodedBer(1);
    fixedAllPacketBerPercent(row)=100*cellResult.allPacketCodedBer(2);
    adaptivePlrPercent(row)=100*cellResult.plr(1);fixedPlrPercent(row)=100*cellResult.plr(2);
    si=find([0;-5;-10;-15;-20]==cellResult.snrDb,1);
    prefix=sprintf('paperCr%d',cellResult.cr);
    target=c.([prefix 'AdaptiveBerPercent']);paperAdaptiveBerPercent(row)=target(si);
    target=c.([prefix 'FixedBerPercent']);paperFixedBerPercent(row)=target(si);
    target=c.([prefix 'AdaptivePlrPercent']);paperAdaptivePlrPercent(row)=target(si);
    target=c.([prefix 'FixedPlrPercent']);paperFixedPlrPercent(row)=target(si);
end
summary=table(cr,snrDb,packetCount,overpasses,adaptiveBerPercent, ...
    paperAdaptiveBerPercent,adaptiveBerPercent-paperAdaptiveBerPercent, ...
    adaptivePlrPercent,paperAdaptivePlrPercent,adaptivePlrPercent-paperAdaptivePlrPercent, ...
    fixedBerPercent,paperFixedBerPercent,fixedBerPercent-paperFixedBerPercent, ...
    fixedPlrPercent,paperFixedPlrPercent,fixedPlrPercent-paperFixedPlrPercent, ...
    adaptiveAllPacketBerPercent,fixedAllPacketBerPercent, ...
    'VariableNames',{'cr','snrDb','packetCount','overpasses','adaptiveBerPercent', ...
    'paperAdaptiveBerPercent','adaptiveBerDeltaPoints','adaptivePlrPercent', ...
    'paperAdaptivePlrPercent','adaptivePlrDeltaPoints','fixedBerPercent', ...
    'paperFixedBerPercent','fixedBerDeltaPoints','fixedPlrPercent', ...
    'paperFixedPlrPercent','fixedPlrDeltaPoints','adaptiveAllPacketBerPercent', ...
    'fixedAllPacketBerPercent'});
end

function localArtifacts(result,output)
writetable(result.table,fullfile(output,'full_phy.csv'));
file=fopen(fullfile(output,'run_status.json'),'w','n','UTF-8');
closer=onCleanup(@()fclose(file));
fprintf(file,'%s\n',jsonencode(struct('status',result.status, ...
    'formal3000Overpasses',result.formal3000Overpasses, ...
    'overpasses',result.config.fullPhyOverpasses, ...
    'directSampleLevelIQ',true,'bandwidthHz',result.config.bandwidthHz, ...
    'centroidPoints',10,'berDefinition',result.config.codedBerDefinition, ...
    'signature',result.signature),'PrettyPrint',true));clear closer
plot_strict_full_phy(result,output);
end
