function audit = audit_strict_paper_reproduction(options)
%AUDIT_STRICT_PAPER_REPRODUCTION Check pure-paper calculations and 3000 passes.
arguments
    options.RequireFormal (1,1) logical = true
end
folder=strictPaperSetup();
tests=run(testsuite(fullfile(folder,'testStrictPaperReproduction.m')));
assert(all([tests.Passed]),'StrictPaper:TestsFailed','A focused test failed.');
tableFolder=fullfile(folder,'results','table_iv_v5_O1');
loaded=load(fullfile(tableFolder,'table_iv.mat'),'result');tableIv=loaded.result;
localIdentity(tableIv,'run_strict_table_iv.m');
assert(strcmp(tableIv.status,'COMPLETE') && tableIv.overpasses==1 && ...
    height(tableIv.table)==5 && all(tableIv.table.packetCount==182));
assert(tableIv.directSampleLevelIQ && tableIv.centroidPointCount==10);
assert(all(abs(tableIv.table.adaptiveSerPercent- ...
    100*tableIv.errors(:,1)./tableIv.table.symbolCount)<1e-12));
assert(all(abs(tableIv.table.fixedSerPercent- ...
    100*tableIv.errors(:,2)./tableIv.table.symbolCount)<1e-12));
localCheckCsv(tableIv.table,fullfile(tableFolder,'table_iv.csv'));
ensemble=load(fullfile(folder,'results','table_iv_v5_O32','table_iv.mat'),'result');
localIdentity(ensemble.result,'run_strict_table_iv.m');
assert(ensemble.result.overpasses==32 && ...
    isequal(ensemble.result.packetErrors(:,1,:,:),tableIv.packetErrors));
gaps=load(fullfile(folder,'results','numerical_gap_audit','numerical_gaps.mat'),'report');
assert(gaps.report.tableIvOverpasses==32 && ~gaps.report.numericalAgreementClaimed);
names={'full_phy_v5_O8_P12_S0_-5_-10_-15_-20','full_phy_v5_O8_Pall_S-10'};
fullRows=0;trajectoryPositions=0;
for experiment=1:numel(names)
    output=fullfile(folder,'results',names{experiment});
    loaded=load(fullfile(output,'full_phy.mat'),'result');result=loaded.result;
    assert(strcmp(result.status,'VALIDATION_COMPLETE') && ~result.formal3000Overpasses);
    localFullPhy(result,output);
    fullRows=fullRows+height(result.table);
    if experiment==2
        trajectoryPositions=sum([result.conditions.packetCount]);
        assert(trajectoryPositions==402);
    end
end
formalFolder=fullfile(folder,'results','full_phy_v5_O3000_Pall_S0_-5_-10_-15_-20');
formalPath=fullfile(formalFolder,'full_phy.mat');
formalComplete=isfile(formalPath);formalRows=0;formalPackets=0;formalSignature='';
if formalComplete
    loaded=load(formalPath,'result');formal=loaded.result;
    assert(strcmp(formal.status,'COMPLETE') && formal.formal3000Overpasses && ...
        formal.config.fullPhyOverpasses==3000 && isinf(formal.config.maximumPackets) && ...
        isequal(formal.config.snrDb,[0;-5;-10;-15;-20]) && numel(formal.conditions)==10);
    localFullPhy(formal,formalFolder);
    formalRows=height(formal.table);formalSignature=formal.signature;
    for index=1:10
        current=formal.conditions(index);
        expected=239;if current.cr==4,expected=163;end
        assert(current.packetCount==expected && current.fullOverpassPacketCount==expected && ...
            current.overpasses==3000);
        formalPackets=formalPackets+current.packetCount*current.overpasses;
    end
    assert(formalPackets==6030000);
elseif options.RequireFormal
    error('StrictPaper:FormalIncomplete','The complete 3000-pass ensemble is required.');
end
status='IMPLEMENTATION_VALIDATED';
if formalComplete,status='FORMAL_COMPLETE_WITH_NUMERICAL_GAPS';end
audit=struct('status',status, ...
    'timestamp',char(datetime('now','Format','yyyy-MM-dd''T''HH:mm:ss')), ...
    'testsPassed',sum([tests.Passed]),'testsFailed',sum([tests.Failed]), ...
    'tableIvRows',height(tableIv.table),'tableIvDiagnosticOverpasses',32, ...
    'fullPhyValidationRows',fullRows,'fullTrajectoryPositions',trajectoryPositions, ...
    'formalRows',formalRows,'formalReceivedPackets',formalPackets, ...
    'formal3000OverpassesComplete',formalComplete, ...
    'directSampleLevelIQ',true,'centroidPoints',10,'bandwidthHz',62600, ...
    'crcFilteredBer',true,'allPacketBerReportedSeparately',true, ...
    'nativeReferenceEquivalenceVerified',true,'exactSourceSignatures',true, ...
    'numericalAgreementClaimed',false,'tableIvSignature',tableIv.signature, ...
    'formalSignature',formalSignature);
file=fopen(fullfile(folder,'results','audit.json'),'w','n','UTF-8');
closer=onCleanup(@()fclose(file));fprintf(file,'%s\n',jsonencode(audit,'PrettyPrint',true));
fprintf('STRICT_AUDIT tests=%d formal3000=%d receivedPackets=%d\n', ...
    audit.testsPassed,formalComplete,formalPackets);
end

function localIdentity(result,runner)
current=strictPaperIdentity(result.config,runner);
assert(strcmp(result.signature,dreConfigurationSignature(current)));
assert(isequal(result.identity.sourceHashes,current.sourceHashes));
assert(result.config.bandwidthHz==62600);
end

function localFullPhy(result,output)
localIdentity(result,'run_strict_full_phy.m');
assert(result.directSampleLevelIQ && result.centroidPointCount==10 && ...
    ~result.receiverUsesPayloadTruth);
for index=1:numel(result.conditions)
    current=result.conditions(index);state=current.rawCounts;
    assert(strcmp(current.status,'COMPLETE') && current.directSampleLevelIQ && ...
        all(state.processedPasses==current.overpasses) && ...
        numel(state.processedPasses)==current.packetCount);
    batchesPerPosition=ceil(current.overpasses/32);
    assert(state.completedBatches==current.packetCount*batchesPerPosition);
    identity=struct('parent',result.signature,'cr',current.cr,'snrDb',current.snrDb, ...
        'batchSize',32,'packetStarts',current.packetStartTimesSec);
    assert(strcmp(current.signature,dreConfigurationSignature(identity)));
    assert(isequal(current.sourceHashes,result.identity.sourceHashes));
    codedBits=result.config.sf*(4+current.cr)*result.config.hammingBlockCount;
    accepted=current.overpasses-state.packetLosses;
    assert(isequal(state.codedBitsAccepted,accepted*codedBits));
    assert(all(state.codedBitsAll==current.overpasses*codedBits,'all'));
    assert(isequal(state.payloadBitsAccepted,accepted*result.config.payloadBitCount));
    fields=fieldnames(state.passCounts);
    for field=1:numel(fields)
        name=fields{field};
        assert(isequal(size(state.passCounts.(name)),[current.overpasses 2]) && ...
            isequal(sum(state.(name),1),sum(state.passCounts.(name),1)));
    end
    assert(all(state.codedErrorsAccepted<=state.codedErrorsAll,'all'));
    assert(all(state.codedErrorsAccepted<=state.codedBitsAccepted,'all'));
    assert(isequaln(current.codedBer,localRate( ...
        sum(state.codedErrorsAccepted,1),sum(state.codedBitsAccepted,1))));
    assert(isequaln(current.trajectoryBer,localRate( ...
        state.codedErrorsAccepted,state.codedBitsAccepted)));
    assert(isequal(current.plr,sum(state.packetLosses,1)/ ...
        (current.packetCount*current.overpasses)));
end
localCheckCsv(result.table,fullfile(output,'full_phy.csv'));
assert(isfile(fullfile(output,'figure_3_CR1.png')) && ...
    isfile(fullfile(output,'figure_4_CR4.png')));
end

function rate=localRate(errors,bits)
rate=nan(size(errors));valid=bits>0;rate(valid)=errors(valid)./bits(valid);
end

function localCheckCsv(expected,path)
actual=readtable(path,'TextType','string');
assert(isequal(expected.Properties.VariableNames,actual.Properties.VariableNames));
for column=1:width(expected)
    a=expected{:,column};b=actual{:,column};
    assert(isequal(isnan(a),isnan(b)));
    valid=~isnan(a);assert(all(abs(a(valid)-b(valid))<1e-10));
end
end
