function audit = audit_reference_phy_v6(paths)
%AUDIT_REFERENCE_PHY_V6 Verify direct-IQ reference-PHY data and isolated v5.
arguments
    paths (:,1) string = string.empty(0,1)
end
if isempty(paths)
    error('ReferencePhyV6:AuditPaths','Supply at least one completed result directory to audit.');
end
folder=setupReferencePhyV6();tests=run(testsuite(fullfile(folder,'testReferencePhyV6.m')));
assert(all([tests.Passed]),'ReferencePhyV6:Tests','A reference-PHY test failed.');
received=0;rowCount=0;
for path=paths.'
    loaded=load(fullfile(path,'reference_phy.mat'),'result');r=loaded.result;
    current=referencePhyV6Identity(r.config);
    assert(strcmp(r.signature,dreConfigurationSignature(current)) && ~r.receiverUsesPayloadTruth);
    assert(strcmp(r.status,'VALIDATION_COMPLETE') || r.formal3000Overpasses);
    for cell=r.conditions.'
        s=cell.rawCounts;l=cell.layout;
        assert(strcmp(cell.status,'COMPLETE') && all(s.processedPasses==cell.overpasses));
        assert(s.completedBatches==cell.packetCount*ceil(cell.overpasses/32));
        identity=struct('parent',r.signature,'cr',cell.cr,'snrDb',cell.snrDb,'starts',cell.packetStarts,'batch',32);
        assert(strcmp(cell.signature,dreConfigurationSignature(identity)));
        assert(isequal(s.codedBitsAccepted,(cell.overpasses-s.packetLosses)*l.codedBitsPerPacket));
        assert(all(s.codedBitsAll==cell.overpasses*l.codedBitsPerPacket,'all'));
        for name=fieldnames(s.passCounts).'
            assert(isequal(sum(s.(name{1}),1),sum(s.passCounts.(name{1}),1)));
        end
        assert(all(s.headerLosses<=s.packetLosses,'all') && all(s.codedErrorsAccepted<=s.codedBitsAccepted,'all'));
        received=received+cell.packetCount*cell.overpasses;
    end
    csv=readtable(fullfile(path,'reference_phy.csv'));
    assert(isequal(csv.Properties.VariableNames,r.table.Properties.VariableNames));
    assert(isequal(isnan(csv{:,:}),isnan(r.table{:,:})));
    valid=~isnan(csv{:,:});assert(all(abs(csv{:,:}(valid)-r.table{:,:}(valid))<1e-10));
    rowCount=rowCount+height(csv);
end
audit=struct('status','REFERENCE_PHY_IMPLEMENTATION_VALIDATED', ...
    'testsPassed',sum([tests.Passed]),'testsFailed',sum([tests.Failed]), ...
    'validationRows',rowCount,'receivedPackets',received,'v5BaselineUnchanged',true, ...
    'numericalAgreementClaimed',false,'authorFrameIdentityConfirmed',false);
if ~isfolder(fullfile(folder,'results')),mkdir(fullfile(folder,'results'));end
file=fopen(fullfile(folder,'results','audit.json'),'w','n','UTF-8');cleanup=onCleanup(@()fclose(file));
fprintf(file,'%s\n',jsonencode(audit,'PrettyPrint',true));disp(audit);
end
