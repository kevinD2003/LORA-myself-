function report = run_loss_forensics_v6(inputPath,options)
%RUN_LOSS_FORENSICS_V6 Reproduce selected cached packets, then explain losses.
arguments
    inputPath (1,:) char
    options.ConditionIndices (:,1) double {mustBeInteger,mustBePositive} = [5;8;9]
end
folder=fileparts(mfilename('fullpath'));strictFolder=fileparts(folder);
addpath(folder,fullfile(strictFolder,'reference_phy_v6'));setupReferencePhyV6;
selected=options.ConditionIndices;
if isempty(selected) || numel(unique(selected))~=numel(selected)
    error('LossForensics:Conditions','Select a nonempty, unique condition list.');
end
if ~isfile(inputPath),error('LossForensics:Input','A completed reference_phy.mat is required.');end
loaded=load(inputPath,'result');parent=loaded.result;c=parent.config;
if ~ismember(parent.status,{'VALIDATION_COMPLETE','FORMAL_COMPLETE_UNCONFIRMED_NUMERICAL_AGREEMENT'}) || ...
        any(selected>numel(parent.conditions)) || c.preambleSymbolCount~=8 || ~isinf(c.maximumPackets)
    error('LossForensics:Input','Use completed full-position v6 results with the frozen eight pilots.');
end
current=referencePhyV6Identity(c);
assert(strcmp(parent.signature,dreConfigurationSignature(current)), ...
    'LossForensics:Source','Parent source/configuration signature does not match.');
sources=dir(fullfile(folder,'*.m'));hashes=strings(numel(sources),2);
for i=1:numel(sources)
    path=fullfile(folder,sources(i).name);hashes(i,:)=[string(path),localHash(path)];
end
identity=struct('parentSignature',parent.signature,'inputSha256',localHash(inputPath), ...
    'sourceHashes',hashes,'conditionIndices',selected, ...
    'schema','posthoc-loss-forensics-v1');
signature=dreConfigurationSignature(identity);
output=fullfile(folder,'results',['loss_forensics_' signature(1:12)]);
keys={'codedErrorsAccepted','codedBitsAccepted','codedErrorsAll', ...
    'codedBitsAll','packetLosses','headerLosses'};
conditions=cell(numel(selected),1);summary=[];
for chosen=1:numel(selected)
    index=selected(chosen);source=parent.conditions(index);
    layout=referencePhyV6Layout(source.cr,c);count=source.packetCount;
    assert(isequal(source.layout,layout) && numel(source.packetStarts)==count && ...
        source.overpasses==c.overpasses && strcmp(source.status,'COMPLETE'));
    positionStats=struct();histogram=zeros(9,2);reproduced=struct('passCounts',struct());
    for key=keys
        reproduced.(key{1})=zeros(count,2);
        reproduced.passCounts.(key{1})=zeros(c.overpasses,2);
    end
    for position=1:count
        stream=RandStream('mt19937ar','Seed',c.randomSeed+1000000000+index*100000+position);
        payload=uint8(randi(stream,[0 255],c.payloadBytes,c.overpasses));
        for firstPass=1:32:c.overpasses
            passes=firstPass:min(firstPass+31,c.overpasses);
            tx=referencePhyV6Encode(payload(:,passes),source.cr,c);
            seeds=c.randomSeed+2000000000+index*5000000+position*10000+passes;
            raw=referencePhyV6Raw(tx.observedSymbols,layout,source.packetStarts(position), ...
                source.snrDb,seeds,c);
            modes={'adaptive','fixed'};
            for method=1:2
                receiver=referencePhyV6LR(raw,layout.observationIndices,8,2^c.sf,modes{method});
                assert(~receiver.usesPayloadTruth);
                % Gold information is supplied only after the receiver has finished.
                detail=summarizePacketLossV6(receiver.detectedSymbols(3:end,:),tx,source.cr,c);
                names=fieldnames(detail.stats);
                for field=1:numel(names)
                    name=names{field};
                    if ~isfield(positionStats,name),positionStats.(name)=zeros(count,2);end
                    positionStats.(name)(position,method)= ...
                        positionStats.(name)(position,method)+detail.stats.(name);
                end
                histogram(:,method)=histogram(:,method)+detail.wordErrorHistogram;
                for key=keys
                    name=key{1};perPacket=['perPacket' upper(name(1)) name(2:end)];
                    reproduced.(name)(position,method)=reproduced.(name)(position,method)+detail.score.(name);
                    reproduced.passCounts.(name)(passes,method)= ...
                        reproduced.passCounts.(name)(passes,method)+detail.score.(perPacket)(:);
                end
            end
        end
        if mod(position,40)==0 || position==count
            fprintf('FORENSICS CR%d SNR%+g %d/%d positions\n',source.cr,source.snrDb,position,count);
        end
    end
    for key=keys
        name=key{1};
        assert(isequal(reproduced.(name),source.rawCounts.(name)) && ...
            isequal(reproduced.passCounts.(name),source.rawCounts.passCounts.(name)), ...
            'LossForensics:Counts','Reproduced counters differ from the saved source.');
    end
    totals=struct();names=fieldnames(positionStats);
    for field=1:numel(names),name=names{field};totals.(name)=sum(positionStats.(name),1);end
    assert(all(totals.rejectedWithoutDecodedNibbleErrorPackets==0));
    if source.cr==4,assert(all(totals.rejectedWithSingleBitWordsOnlyPackets==0));end
    assert(all(totals.packetCount==count*c.overpasses));
    conditions{chosen}=struct('sourceConditionIndex',index,'cr',source.cr,'snrDb',source.snrDb, ...
        'packetStarts',source.packetStarts,'positionStats',positionStats,'totals',totals, ...
        'wordErrorHistogram',histogram,'reproducedCounts',reproduced,'countersMatchParent',true);
    for method=1:2
        summary(end+1,:)=[source.cr source.snrDb method totals.packetCount(method) ...
            totals.acceptedPackets(method) totals.headerRejectedPackets(method) ...
            totals.crcRejectedValidHeaderPackets(method) totals.rejectedWithMultiBitWordPackets(method) ...
            totals.rejectedWithSingleBitWordsOnlyPackets(method) ...
            totals.acceptedWithWrongPayloadPackets(method) totals.acceptedWithCodedErrorPackets(method)]; %#ok<AGROW>
    end
end
table=array2table(summary,'VariableNames',{'cr','snrDb','method','packets','accepted', ...
    'headerRejected','crcRejectedValidHeader','rejectedWithMultiBitWord', ...
    'rejectedWithSingleBitWordsOnly','acceptedWrongPayload','acceptedWithCodedErrors'});
report=struct('status','FORENSICS_REPRODUCED_PARENT_COUNTS','identity',identity, ...
    'signature',signature,'conditions',vertcat(conditions{:}),'table',table, ...
    'receivedPackets',sum(summary(:,4))/2,'receiverUsesPayloadTruth',false, ...
    'goldUsedOnlyForPosthocDiagnostics',true,'numericalAgreementClaimed',false, ...
    'outputDirectory',output);
if ~isfolder(output),mkdir(output);end
save(fullfile(output,'loss_forensics.mat'),'report','-v7.3');
metadata=rmfield(report,{'conditions','table'});metadata.summary=table2struct(table);
path=fullfile(output,'loss_forensics.json');file=fopen(path,'w','n','UTF-8');
if file<0,error('LossForensics:Output','Cannot open output file.');end
cleanup=onCleanup(@()fclose(file));fprintf(file,'%s\n',jsonencode(metadata,'PrettyPrint',true));clear cleanup
disp(table);disp(output);
end
function sha = localHash(path)
file=fopen(path,'rb');if file<0,error('LossForensics:Source','Missing source file.');end
cleanup=onCleanup(@()fclose(file));bytes=fread(file,Inf,'*uint8');
digest=java.security.MessageDigest.getInstance('SHA-256');digest.update(bytes);
sha=string(lower(reshape(dec2hex(typecast(digest.digest(),'uint8'),2).',1,[])));
end
