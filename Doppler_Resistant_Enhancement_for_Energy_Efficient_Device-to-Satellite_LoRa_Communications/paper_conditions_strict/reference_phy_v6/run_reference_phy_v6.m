function result = run_reference_phy_v6(options)
%RUN_REFERENCE_PHY_V6 New reference-PHY ensemble, isolated from frozen v5.
arguments
    options.Overpasses (1,1) double {mustBeInteger,mustBePositive} = 8
    options.MaximumPackets (1,1) double {mustBePositive} = Inf
    options.MaximumBatchesPerCall (1,1) double {mustBePositive} = Inf
    options.SnrDb (:,1) double = -10
    options.PhaseModel (1,:) char {mustBeMember(options.PhaseModel, ...
        {'paper-equation-15-product','integrated-instantaneous-doppler'})} = 'paper-equation-15-product'
end
folder=setupReferencePhyV6();c=referencePhyV6Config();c.phaseModel=options.PhaseModel;
if options.Overpasses>10000 || isempty(options.SnrDb) || ...
        any(~ismember(options.SnrDb,[0 -5 -10 -15 -20])) || numel(unique(options.SnrDb))~=numel(options.SnrDb) || ...
        (isfinite(options.MaximumPackets) && options.MaximumPackets~=fix(options.MaximumPackets))
    error('ReferencePhyV6:Conditions','Use distinct paper SNRs and integer packet/pass counts.');
end
c.overpasses=options.Overpasses;c.maximumPackets=options.MaximumPackets;c.snrDb=options.SnrDb;
identity=referencePhyV6Identity(c);signature=dreConfigurationSignature(identity);
packetTag='all';if isfinite(options.MaximumPackets),packetTag=sprintf('%d',options.MaximumPackets);end
phaseTag='product';if contains(c.phaseModel,'integrated'),phaseTag='integrated';end
output=fullfile(folder,'results',sprintf('reference_phy_v6_O%d_P%s_S%s_%s_%s', ...
    options.Overpasses,packetTag,strjoin(cellstr(string(options.SnrDb.')),'_'),phaseTag,signature(1:12)));
if ~isfolder(output),mkdir(output);end
path=fullfile(output,'reference_phy.mat');
if isfile(path)
    cached=load(path,'result');assert(strcmp(cached.result.signature,signature), ...
        'ReferencePhyV6:Cache','Source/configuration changed; do not migrate this cache.');
    result=cached.result;return
end
cells=cell(2*numel(options.SnrDb),1);cellIndex=0;used=0;
for cr=[1 4]
    for snr=options.SnrDb.'
        cellIndex=cellIndex+1;layout=referencePhyV6Layout(cr,c);
        orbit=drePaperOrbit(0,c);starts=(-orbit.horizonTimeSec:layout.durationSec: ...
            orbit.horizonTimeSec-layout.durationSec).';fullCount=numel(starts);
        if isfinite(c.maximumPackets) && fullCount>c.maximumPackets
            starts=starts(unique(round(linspace(1,fullCount,c.maximumPackets))));
        end
        cellFolder=fullfile(output,sprintf('CR%d_SNR%+d',cr,snr));
        if ~isfolder(cellFolder),mkdir(cellFolder);end
        cellIdentity=struct('parent',signature,'cr',cr,'snrDb',snr,'starts',starts,'batch',32);
        cellSignature=dreConfigurationSignature(cellIdentity);
        savedPath=fullfile(cellFolder,'cell.mat');checkpoint=fullfile(cellFolder,'checkpoint.mat');
        if isfile(savedPath)
            loaded=load(savedPath,'condition');assert(strcmp(loaded.condition.signature,cellSignature));
            cells{cellIndex}=loaded.condition;continue
        end
        count=numel(starts);batchesPerPosition=ceil(c.overpasses/32);totalBatches=count*batchesPerPosition;
        fields={'codedErrorsAccepted','codedBitsAccepted','codedErrorsAll','codedBitsAll','packetLosses','headerLosses'};
        state=struct('completedBatches',0,'processedPasses',zeros(count,1),'passCounts',struct());
        if isfile(checkpoint)
            loaded=load(checkpoint,'state','savedSignature');assert(strcmp(loaded.savedSignature,cellSignature));
            state=loaded.state;
        else
            for name=fields
                state.(name{1})=zeros(count,2);state.passCounts.(name{1})=zeros(c.overpasses,2);
            end
        end
        payloadIndex=0;payload=[];
        for batch=state.completedBatches+1:totalBatches
            if used>=options.MaximumBatchesPerCall,break;end
            position=floor((batch-1)/batchesPerPosition)+1;
            within=mod(batch-1,batchesPerPosition)+1;
            passes=(within-1)*32+1:min(within*32,c.overpasses);
            if payloadIndex~=position
                stream=RandStream('mt19937ar','Seed',c.randomSeed+1000000000+cellIndex*100000+position);
                payload=uint8(randi(stream,[0 255],c.payloadBytes,c.overpasses));payloadIndex=position;
            end
            tx=referencePhyV6Encode(payload(:,passes),cr,c);
            seeds=c.randomSeed+2000000000+cellIndex*5000000+position*10000+passes;
            raw=referencePhyV6Raw(tx.observedSymbols,layout,starts(position),snr,seeds,c);
            modes={'adaptive','fixed'};
            for method=1:2
                receiver=referencePhyV6LR(raw,layout.observationIndices,8,2^c.sf,modes{method});
                % First two hard decisions are sync upchirps, not PHY data.
                metrics=referencePhyV6Score(receiver.detectedSymbols(3:end,:),tx,cr,c);
                for name=fields
                    key=name{1};perPacket=['perPacket' upper(key(1)) key(2:end)];
                    state.(key)(position,method)=state.(key)(position,method)+metrics.(key);
                    state.passCounts.(key)(passes,method)=state.passCounts.(key)(passes,method)+metrics.(perPacket)(:);
                end
            end
            state.processedPasses(position)=state.processedPasses(position)+numel(passes);
            state.completedBatches=batch;used=used+1;
            if mod(batch,10)==0 || batch==totalBatches || used>=options.MaximumBatchesPerCall
                savedSignature=cellSignature; %#ok<NASGU>
                save([checkpoint '.tmp'],'state','savedSignature','-v7.3');movefile([checkpoint '.tmp'],checkpoint,'f');
                progress=struct('completedBatches',batch,'totalBatches',totalBatches, ...
                    'processedPackets',sum(state.processedPasses),'totalPackets',count*c.overpasses, ...
                    'signature',cellSignature);
                localJson(fullfile(cellFolder,'progress.json'),progress);
                fprintf('REFERENCE_V6 CR%d SNR%+g %s %d/%d batches\n',cr,snr,phaseTag,batch,totalBatches);
            end
        end
        if state.completedBatches<totalBatches
            result=struct('status','CHECKPOINTED','signature',signature,'outputDirectory',output);return
        end
        assert(all(state.processedPasses==c.overpasses));
        condition=struct('status','COMPLETE','signature',cellSignature,'cr',cr,'snrDb',snr, ...
            'packetCount',count,'fullPacketCount',fullCount,'overpasses',c.overpasses, ...
            'packetStarts',starts,'layout',layout,'rawCounts',state); %#ok<NASGU>
        save([savedPath '.tmp'],'condition','-v7.3');movefile([savedPath '.tmp'],savedPath,'f');
        cells{cellIndex}=condition;
    end
end
conditions=vertcat(cells{:});rows=[];
for i=1:numel(conditions)
    current=conditions(i);s=current.rawCounts;
    for method=1:2
        ber=NaN;if sum(s.codedBitsAccepted(:,method))>0
            ber=100*sum(s.codedErrorsAccepted(:,method))/sum(s.codedBitsAccepted(:,method));
        end
        allBer=100*sum(s.codedErrorsAll(:,method))/sum(s.codedBitsAll(:,method));
        plr=100*sum(s.packetLosses(:,method))/(current.packetCount*c.overpasses);
        headerPlr=100*sum(s.headerLosses(:,method))/(current.packetCount*c.overpasses);
        rows(end+1,:)=[current.cr current.snrDb method current.packetCount c.overpasses ...
            ber allBer plr headerPlr current.layout.onAirSymbols current.layout.codedBitsPerPacket]; %#ok<AGROW>
    end
end
summary=array2table(rows,'VariableNames',{'cr','snrDb','method','packetCount','overpasses', ...
    'crcSuccessCodedBerPercent','allPacketCodedBerPercent','plrPercent','headerLossPercent', ...
    'onAirSymbols','codedBitsPerPacket'});
isFormal=c.overpasses==3000 && isinf(c.maximumPackets) && isequal(c.snrDb,[0;-5;-10;-15;-20]);
status='VALIDATION_COMPLETE';if isFormal,status='FORMAL_COMPLETE_UNCONFIRMED_NUMERICAL_AGREEMENT';end
result=struct('status',status,'config',c,'identity',identity,'signature',signature, ...
    'conditions',conditions,'table',summary,'formal3000Overpasses',isFormal, ...
    'numericalAgreementClaimed',false,'receiverUsesPayloadTruth',false,'outputDirectory',output);
save(path,'result','-v7.3');writetable(summary,fullfile(output,'reference_phy.csv'));
localJson(fullfile(output,'run_status.json'),struct('status',status,'signature',signature, ...
    'receivedPackets',sum([conditions.packetCount])*c.overpasses,'formal3000',isFormal, ...
    'numericalAgreementClaimed',false));
disp(summary);
end
function localJson(path,data)
file=fopen([path '.tmp'],'w','n','UTF-8');cleanup=onCleanup(@()fclose(file));
fprintf(file,'%s\n',jsonencode(data,'PrettyPrint',true));clear cleanup
movefile([path '.tmp'],path,'f');
end
