function report = run_reference_soft_phy(inputPath,options)
%RUN_REFERENCE_SOFT_PHY Standard soft option, paired against an immutable v6 run.
arguments
    inputPath (1,:) char
    options.ConditionIndices (:,1) double {mustBeInteger,mustBePositive} = (1:10).'
    options.MaximumPositions (1,1) double {mustBePositive} = Inf
    options.SoftWindow (1,:) char {mustBeMember(options.SoftWindow,{'reference-rectangular','paper-hann'})} = 'paper-hann'
end
folder=setupReferenceSoftPhy;selected=options.ConditionIndices;limit=options.MaximumPositions;
if isempty(selected) || numel(unique(selected))~=numel(selected) || isnan(limit) || ...
        (isfinite(limit) && limit~=fix(limit))
    error('ReferenceSoft:Conditions','Use a nonempty unique condition list and integer position limit.');
end
identity=referenceSoftIdentity(inputPath,selected,limit,options.SoftWindow);
loaded=load(identity.inputPath,'result');parent=loaded.result;c=parent.config;
if ~ismember(parent.status,{'VALIDATION_COMPLETE','FORMAL_COMPLETE_UNCONFIRMED_NUMERICAL_AGREEMENT'}) || ...
        any(selected>numel(parent.conditions)) || c.preambleSymbolCount~=8 || ~isinf(c.maximumPackets)
    error('ReferenceSoft:Input','Use completed full-position v6 results with eight pilots.');
end
signature=dreConfigurationSignature(identity);
output=fullfile(folder,'results',['paired_soft_' signature(1:12)]);
path=fullfile(output,'paired_soft.mat');
if isfile(path)
    stored=load(path,'report');assert(strcmp(stored.report.signature,signature));report=stored.report;return
end
basic={'codedErrorsAccepted','codedBitsAccepted','codedErrorsAll','codedBitsAll','packetLosses','headerLosses'};
softKeys=[basic {'llrSignErrorsAccepted','llrSignErrorsAll','acceptedWrongPayload'}];
pairedKeys={'bothAccepted','hardOnlyAccepted','softOnlyAccepted','bothRejected'};
conditions=cell(numel(selected),1);summary=[];allPositions=true;
targetPath=fullfile(fileparts(folder),'results','full_phy_v5_O3000_Pall_S0_-5_-10_-15_-20','full_phy.mat');
targetData=load(targetPath,'result');targets=targetData.result.table;
for chosen=1:numel(selected)
    index=selected(chosen);source=parent.conditions(index);layout=referencePhyV6Layout(source.cr,c);
    assert(isequal(source.layout,layout) && source.overpasses==c.overpasses && strcmp(source.status,'COMPLETE'));
    positions=(1:source.packetCount).';
    if isfinite(limit) && numel(positions)>limit
        positions=unique(round(linspace(1,source.packetCount,limit))).';
    end
    count=numel(positions);full=count==source.packetCount;allPositions=allPositions && full;
    hard=localState(count,c.overpasses,basic);soft=localState(count,c.overpasses,softKeys);
    paired=struct();for key=pairedKeys,paired.(key{1})=zeros(count,2);end
    clipped=zeros(count,2);
    for slot=1:count
        position=positions(slot);
        stream=RandStream('mt19937ar','Seed',c.randomSeed+1000000000+index*100000+position);
        payload=uint8(randi(stream,[0 255],c.payloadBytes,c.overpasses));
        for firstPass=1:32:c.overpasses
            passes=firstPass:min(firstPass+31,c.overpasses);
            tx=referencePhyV6Encode(payload(:,passes),source.cr,c);
            seeds=c.randomSeed+2000000000+index*5000000+position*10000+passes;
            [raw,iq]=referencePhyV6Raw(tx.observedSymbols,layout,source.packetStarts(position),source.snrDb,seeds,c);
            modes={'adaptive','fixed'};
            for method=1:2
                [prediction,receiver]=referenceSoftPredictions(raw,layout.observationIndices,c,modes{method});
                old=referencePhyV6Score(receiver.detectedSymbols(3:end,:),tx,source.cr,c);
                rx=referenceSoftDecode(iq,prediction,source.cr,c,options.SoftWindow);
                % Gold enters scoring only after both independent receive paths finish.
                next=referenceSoftScore(rx,old,tx);
                hard=localAccumulate(hard,old,basic,slot,passes,method);
                soft=localAccumulate(soft,next,softKeys,slot,passes,method);
                masks={old.crcPass & rx.crcPass,old.crcPass & ~rx.crcPass, ...
                    ~old.crcPass & rx.crcPass,~old.crcPass & ~rx.crcPass};
                for k=1:4,paired.(pairedKeys{k})(slot,method)=paired.(pairedKeys{k})(slot,method)+sum(masks{k});end
                clipped(slot,method)=clipped(slot,method)+sum(rx.clippedSymbols(:));
                assert(~receiver.usesPayloadTruth && ~rx.usesPayloadTruth && ~rx.softFeedbackIntoLR);
            end
        end
        if mod(slot,40)==0 || slot==count
            fprintf('SOFT_PAIRED %s CR%d SNR%+g %d/%d positions\n',options.SoftWindow,source.cr,source.snrDb,slot,count);
        end
    end
    for key=basic
        name=key{1};assert(isequal(hard.(name),source.rawCounts.(name)(positions,:)), ...
            'ReferenceSoft:HardCounts','Per-position hard counters do not match frozen input.');
        if full
            assert(isequal(hard.passCounts.(name),source.rawCounts.passCounts.(name)), ...
                'ReferenceSoft:HardCounts','Per-overpass hard counters do not match frozen input.');
        end
        assert(isequal(sum(hard.(name),1),sum(hard.passCounts.(name),1)));
        assert(isequal(sum(soft.(name),1),sum(soft.passCounts.(name),1)));
    end
    assert(isequal(soft.codedErrorsAll,hard.codedErrorsAll) && isequal(soft.codedBitsAll,hard.codedBitsAll));
    assert(all(paired.bothAccepted+paired.hardOnlyAccepted+paired.softOnlyAccepted+paired.bothRejected==c.overpasses,'all'));
    assert(isequal(soft.packetLosses,hard.packetLosses+paired.hardOnlyAccepted-paired.softOnlyAccepted));
    assert(all(soft.codedBitsAccepted<=soft.codedBitsAll,'all'));
    conditions{chosen}=struct('sourceConditionIndex',index,'cr',source.cr,'snrDb',source.snrDb, ...
        'positions',positions,'packetStarts',source.packetStarts(positions),'layout',layout, ...
        'hard',hard,'soft',soft,'paired',paired,'clippedSymbols',clipped, ...
        'parentPositionCountersMatched',true,'parentPassCountersChecked',full);
    target=targets(targets.cr==source.cr & targets.snrDb==source.snrDb,:);assert(height(target)==1);
    for method=1:2
        paperBer=target.paperAdaptiveBerPercent;paperPlr=target.paperAdaptivePlrPercent;
        if method==2,paperBer=target.paperFixedBerPercent;paperPlr=target.paperFixedPlrPercent;end
        denominator=sum(soft.codedBitsAccepted(:,method));softBer=NaN;signBer=NaN;
        if denominator>0
            softBer=100*sum(soft.codedErrorsAccepted(:,method))/denominator;
            signBer=100*sum(soft.llrSignErrorsAccepted(:,method))/denominator;
        end
        hardDen=sum(hard.codedBitsAccepted(:,method));hardBer=NaN;
        if hardDen>0,hardBer=100*sum(hard.codedErrorsAccepted(:,method))/hardDen;end
        packets=count*c.overpasses;
        hardPlr=100*sum(hard.packetLosses(:,method))/packets;softPlr=100*sum(soft.packetLosses(:,method))/packets;
        berGap=abs(softBer-paperBer);plrGap=abs(softPlr-paperPlr);
        summary(end+1,:)=[source.cr source.snrDb method count c.overpasses hardBer softBer signBer ...
            hardPlr softPlr paperBer paperPlr berGap plrGap ...
            isfinite(berGap)&&berGap<=5 isfinite(plrGap)&&plrGap<=5 ...
            sum(paired.softOnlyAccepted(:,method)) sum(paired.hardOnlyAccepted(:,method)) ...
            100*sum(soft.headerLosses(:,method))/packets sum(soft.acceptedWrongPayload(:,method))]; %#ok<AGROW>
    end
end
table=array2table(summary,'VariableNames',{'cr','snrDb','method','positionCount','overpasses', ...
    'hardCrcSuccessCodedBerPercent','softCrcSuccessCodedBerPercent','softLlrSignCodedBerPercent', ...
    'hardPlrPercent','softPlrPercent','paperBerPercent','paperPlrPercent','softBerGapPoints', ...
    'softPlrGapPoints','softBerWithin5pp','softPlrWithin5pp','softOnlyAccepted','hardOnlyAccepted', ...
    'softHeaderLossPercent','softAcceptedWrongPayload'});
table.softBerWithin5pp=logical(table.softBerWithin5pp);table.softPlrWithin5pp=logical(table.softPlrWithin5pp);
fullGrid=allPositions && numel(selected)==10 && numel(parent.conditions)==10 && ...
    isequal(sort(selected),(1:10).') && isequal(sort(unique(table.snrDb)),[-20;-15;-10;-5;0]);
passes=nnz(table.softBerWithin5pp)+nnz(table.softPlrWithin5pp);
formal=fullGrid && parent.formal3000Overpasses;
status='PAIRED_SOFT_SAMPLE_COMPLETE';if allPositions,status='PAIRED_SOFT_VALIDATION_COMPLETE';end
if formal,status='PAIRED_SOFT_FORMAL_COMPLETE_AUTHOR_UNCONFIRMED';end
report=struct('status',status,'identity',identity,'signature',signature,'config',c, ...
    'softWindow',options.SoftWindow, ...
    'conditions',vertcat(conditions{:}),'table',table,'receivedPackets',sum(summary(:,4).*summary(:,5))/2, ...
    'checkedMetrics',2*height(table),'metricsWithin5pp',passes,'fullGridWithAllPositions',fullGrid, ...
    'validationToleranceMet',fullGrid && passes==40,'formal3000Overpasses',formal, ...
    'formalAcceptanceConfirmed',formal && passes==40,'authorDecoderModeConfirmed',false, ...
    'numericalAgreementClaimed',false,'receiverUsesPayloadTruth',false,'softFeedbackIntoLR',false, ...
    'primaryCodedBerStream','same LR-hard pre-Hamming bits, codec-specific CRC-success mask', ...
    'diagnosticCodedBerStream','LLR-sign bits before ML','outputDirectory',output);
if ~isfolder(output),mkdir(output);end
save(path,'report','-v7.3');
metadata=rmfield(report,{'conditions','table'});metadata.summary=table2struct(table);
file=fopen(fullfile(output,'paired_soft.json'),'w','n','UTF-8');
if file<0,error('ReferenceSoft:Output','Cannot open metadata output.');end
cleanup=onCleanup(@()fclose(file));fprintf(file,'%s\n',jsonencode(metadata,'PrettyPrint',true));clear cleanup
disp(table(:,{'cr','snrDb','method','hardPlrPercent','softPlrPercent','softCrcSuccessCodedBerPercent', ...
    'softBerWithin5pp','softPlrWithin5pp'}));disp(output);
end
function state = localState(count,passes,keys)
state=struct('passCounts',struct());
for key=keys,state.(key{1})=zeros(count,2);state.passCounts.(key{1})=zeros(passes,2);end
end
function state = localAccumulate(state,metrics,keys,slot,passes,method)
for key=keys
    name=key{1};perPacket=['perPacket' upper(name(1)) name(2:end)];
    state.(name)(slot,method)=state.(name)(slot,method)+metrics.(name);
    state.passCounts.(name)(passes,method)=state.passCounts.(name)(passes,method)+metrics.(perPacket)(:);
end
end
