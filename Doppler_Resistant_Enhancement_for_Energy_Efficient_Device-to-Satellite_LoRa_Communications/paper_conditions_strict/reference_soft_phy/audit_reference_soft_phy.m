function audit = audit_reference_soft_phy(paths)
%AUDIT_REFERENCE_SOFT_PHY Source/paired-count integrity, not author identity.
arguments
    paths (:,1) string = strings(0,1)
end
if isempty(paths),error('ReferenceSoft:AuditPaths','Completed result directories are required.');end
folder=setupReferenceSoftPhy;
tests=run(testsuite(fullfile(folder,'testReferenceSoftPhy.m')));assert(all([tests.Passed]));
packets=0;rows=0;
for path=paths.'
    loaded=load(fullfile(path,'paired_soft.mat'),'report');r=loaded.report;
    id=referenceSoftIdentity(r.identity.inputPath,r.identity.conditionIndices,r.identity.maximumPositions,r.softWindow);
    assert(strcmp(r.signature,dreConfigurationSignature(id)) && ...
        ~r.receiverUsesPayloadTruth && ~r.softFeedbackIntoLR && ~r.authorDecoderModeConfirmed);
    parentData=load(id.inputPath,'result');parent=parentData.result;
    assert(isequal(r.config,parent.config) && ...
        isequal([r.conditions.sourceConditionIndex].',id.conditionIndices) && ...
        height(r.table)==2*numel(r.conditions));
    targetData=load(id.targetPath,'result');targets=targetData.result.table;
    for i=1:numel(r.conditions)
        current=r.conditions(i);source=parent.conditions(current.sourceConditionIndex);p=current.positions;
        assert(numel(p)==numel(unique(p)) && all(p>=1 & p<=source.packetCount));
        assert(current.cr==source.cr && current.snrDb==source.snrDb && ...
            current.parentPassCountersChecked==isequal(p,(1:source.packetCount).'));
        for name={'codedErrorsAccepted','codedBitsAccepted','codedErrorsAll','codedBitsAll','packetLosses','headerLosses'}
            key=name{1};assert(isequal(current.hard.(key),source.rawCounts.(key)(p,:)));
            assert(isequal(sum(current.soft.(key),1),sum(current.soft.passCounts.(key),1)));
            assert(isequal(sum(current.hard.(key),1),sum(current.hard.passCounts.(key),1)));
            if current.parentPassCountersChecked
                assert(isequal(p,(1:source.packetCount).') && ...
                    isequal(current.hard.passCounts.(key),source.rawCounts.passCounts.(key)));
            end
        end
        paired=current.paired;
        assert(all(paired.bothAccepted+paired.hardOnlyAccepted+paired.softOnlyAccepted+paired.bothRejected==r.config.overpasses,'all'));
        assert(isequal(current.soft.packetLosses,current.hard.packetLosses+paired.hardOnlyAccepted-paired.softOnlyAccepted));
        assert(isequal(current.soft.codedErrorsAll,current.hard.codedErrorsAll));
        assert(isequal(current.soft.codedBitsAll,current.hard.codedBitsAll));
        assert(all(current.soft.codedBitsAccepted== ...
            (r.config.overpasses-current.soft.packetLosses)*current.layout.codedBitsPerPacket,'all'));
        assert(all(current.soft.headerLosses<=current.soft.packetLosses,'all'));
        assert(all(current.soft.codedErrorsAccepted<=current.soft.codedBitsAccepted,'all'));
        target=targets(targets.cr==current.cr & targets.snrDb==current.snrDb,:);assert(height(target)==1);
        for method=1:2
            line=r.table(r.table.cr==current.cr & r.table.snrDb==current.snrDb & r.table.method==method,:);assert(height(line)==1);
            ber=NaN;den=sum(current.soft.codedBitsAccepted(:,method));
            if den>0,ber=100*sum(current.soft.codedErrorsAccepted(:,method))/den;end
            plr=100*sum(current.soft.packetLosses(:,method))/(numel(p)*r.config.overpasses);
            assert(isequaln(ber,line.softCrcSuccessCodedBerPercent) && plr==line.softPlrPercent);
            paperBer=target.paperAdaptiveBerPercent;paperPlr=target.paperAdaptivePlrPercent;
            if method==2,paperBer=target.paperFixedBerPercent;paperPlr=target.paperFixedPlrPercent;end
            assert(line.paperBerPercent==paperBer && line.paperPlrPercent==paperPlr);
            assert(line.softBerWithin5pp==(isfinite(ber) && abs(ber-line.paperBerPercent)<=5));
            assert(line.softPlrWithin5pp==(abs(plr-line.paperPlrPercent)<=5));
        end
        packets=packets+numel(p)*r.config.overpasses;
    end
    assert(r.receivedPackets==sum(arrayfun(@(current)numel(current.positions),r.conditions))*r.config.overpasses);
    assert(r.checkedMetrics==2*height(r.table) && ...
        r.metricsWithin5pp==nnz(r.table.softBerWithin5pp)+nnz(r.table.softPlrWithin5pp));
    full=all([r.conditions.parentPassCountersChecked]) && numel(r.conditions)==10 && ...
        numel(parent.conditions)==10 && isequal(sort(id.conditionIndices),(1:10).') && ...
        isequal(sort(unique(r.table.snrDb)),[-20;-15;-10;-5;0]);
    assert(r.fullGridWithAllPositions==full && r.formal3000Overpasses==(full && parent.formal3000Overpasses));
    assert(r.validationToleranceMet==(r.fullGridWithAllPositions && r.metricsWithin5pp==40));
    assert(r.formalAcceptanceConfirmed==(r.formal3000Overpasses && r.metricsWithin5pp==40));
    rows=rows+height(r.table);
end
audit=struct('status','STANDARD_SOFT_IMPLEMENTATION_VALIDATED','testsPassed',nnz([tests.Passed]), ...
    'testsFailed',nnz([tests.Failed]),'resultRows',rows,'receivedPackets',packets, ...
    'pairedHardCountersMatched',true,'softFeedbackIntoLR',false, ...
    'authorDecoderModeConfirmed',false,'numericalAgreementClaimed',false);
file=fopen(fullfile(folder,'results','audit.json'),'w','n','UTF-8');
if file<0,error('ReferenceSoft:Output','Cannot write audit metadata.');end
cleanup=onCleanup(@()fclose(file));fprintf(file,'%s\n',jsonencode(audit,'PrettyPrint',true));clear cleanup
disp(audit);
end
