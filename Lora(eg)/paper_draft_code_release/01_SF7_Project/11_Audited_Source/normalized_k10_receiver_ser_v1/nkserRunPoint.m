function summary=nkserRunPoint(localIndex,cohort,options)
%NKSERRUNPOINT Resumable SER-only receiver run for one normalized-K10 point.
arguments
    localIndex (1,1) double {mustBeInteger,mustBeInRange(localIndex,1,50)}
    cohort (1,1) string {mustBeMember(cohort,["smoke","gate100","formal1000"])}="gate100"
    options.StopAfterPackets (1,1) double {mustBePositive}=Inf
end
oldPath=path;restore=onCleanup(@()path(oldPath));roots=nkserSetup();
[points,configs]=nkserProjectConditions();p=points(localIndex);
config=configs{1+(p.sf==12)};c=config.parent;
if cohort=="smoke"
    planned=2;seedRoot=2990000000;
elseif cohort=="gate100"
    planned=100;seedRoot=3000000000;
    assert(ismember(localIndex,[10 20 25 35 45 50]), ...
        'NkSer:GatePoint','The structure gate contains exactly six registered endpoints.');
else
    planned=1000;seedRoot=3100000000;requireGate(roots.root);
end
identity=struct('experimentId','normalized-k10-receiver-ser-v1', ...
    'pointId',p.id,'point',p,'cohort',char(cohort),'plannedPackets',planned, ...
    'seedRoot',seedRoot,'packetSeedBase',seedRoot+p.originalIndex*100000, ...
    'packetSeedStride',8,'profileId',config.channelProfile.id, ...
    'profileSha256',nkserHash(roots.profilePath),'kDb',10, ...
    'ensembleTotalPower',1,'linkMarginDb',0,'perPacketNormalization',false, ...
    'codeProvenance',nkserProvenance(roots.root),'matlabVersion',version, ...
    'receiverIdentity',roots.receiverIdentity,'vpHistoryLength',8, ...
    'methodIds',{{'prec','vp','paper','idealNative','idealPaper'}}, ...
    'metric','pre-FEC-FFT-hard-chirp-SER-only','dataChirps',112, ...
    'failurePolicy','receiver failure contributes 112 errors; no drop or replacement', ...
    'idealPolicy','remove common Doppler only; retain fading, ISI, and rotated noise');
identityText=jsonencode(identity);signature=nkserHash(identityText,false);
directory=fullfile(roots.root,'results',char(cohort),p.id);
if ~isfolder(directory),mkdir(directory);end
checkpoint=fullfile(directory,'CHECKPOINT.mat');
methods={'prec','vp','paper','idealNative','idealPaper'};
names={'packetId','payloadSeed','noiseSeed','channelSeed','paperExtraNoiseSeed','noiseVariance'};
for k=1:numel(methods)
    names=[names {[methods{k} 'Errors'],[methods{k} 'Failure']}]; %#ok<AGROW>
end
names=[names {'runtimeCommonSec','runtimePrecSec','runtimeVpSec','runtimePaperSec', ...
    'vpAcceptedSymbols','vpUsedSymbols','vpRateUpdates','noisePowerEstimate', ...
    'realizedTapEnergy','nativeCleanPower','paperCleanPower'}];
if isfile(checkpoint)
    loaded=load(checkpoint,'state');state=loaded.state;
    assert(strcmp(state.signature,signature)&&strcmp(state.identityText,identityText), ...
        'NkSer:Identity','Checkpoint source/configuration/seed identity changed.');
else
    state=struct('signature',signature,'identity',identity,'identityText',identityText, ...
        'raw',zeros(0,numel(names)),'truthBins',zeros(0,112,'uint16'), ...
        'bins',struct(),'failureMessages',strings(0,5));
    for k=1:5,state.bins.(methods{k})=zeros(0,112,'uint16');end
end
assert(isequal(state.raw(:,1),(1:size(state.raw,1)).'),'NkSer:Continuity','Packet gap.');
stop=min(planned,options.StopAfterPackets);timer=tic;
for packet=size(state.raw,1)+1:stop
    seed=identity.packetSeedBase+packet*identity.packetSeedStride;
    seeds=struct('payloadSeed',seed,'noiseSeed',seed+1, ...
        'channelSeed',seed+2,'paperExtraNoiseSeed',seed+3);
    pair=nk10GeneratePair(config,p.orbitStartSec,p.snrDb,seeds);
    actual=acDecodeMethods(pair,config);
    truth=pair.native.truth.payloadPhysicalBins(:);
    assert(isequal(truth,pair.pilot.truth.payloadPhysicalBins(:))&&numel(truth)==112);
    row=[packet seed seed+1 seed+2 seed+3 pair.power.noiseVariance];
    messages=strings(1,5);keys={'PREC','VP','Paper'};
    for k=1:5
        failed=false;message="";
        if k<=3
            failed=actual.failures.(keys{k});message=actual.messages.(keys{k});
            if failed
                bins=repmat(65535,112,1);
            else
                bins=actual.(keys{k}).detectedPhysicalBins(:);
            end
        else
            if k==4
                frame=pair.nativeIdeal;layout=pair.native.observation.layout;
            else
                frame=pair.pilotIdeal;layout=pair.pilot.observation.layout;
            end
            try
                ideal=prefecNativeHardDetect(frame.rxPhysical(layout.dataRows,:),c);
                bins=ideal.detectedPhysicalBins(:);
                assert(numel(bins)==112&&all(isfinite(bins))&& ...
                    all(bins==fix(bins)&bins>=0&bins<c.dataAlphabetSize));
            catch problem
                failed=true;message=string(problem.identifier)+": "+string(problem.message);
                bins=repmat(65535,112,1);
            end
        end
        errors=nnz(bins~=truth);
        if failed,assert(errors==112,'NkSer:FailureAccounting','Failure must count 112 errors.');end
        row=[row errors double(failed)]; %#ok<AGROW>
        state.bins.(methods{k})(packet,:)=uint16(bins.');messages(k)=message;
    end
    accepted=NaN;used=NaN;rateUpdates=NaN;
    if ~actual.failures.VP
        accepted=actual.VP.acceptedVirtualPilots;used=actual.VP.usedVirtualPilots;
        rateUpdates=sum(actual.VP.fitLog.rateUpdated);
    end
    rt=actual.runtimeSec;
    row=[row rt.common rt.PREC rt.VP rt.Paper accepted used rateUpdates ...
        actual.noisePowerEstimate pair.power.realizedTapEnergy ...
        pair.power.measuredNativeCleanPower pair.power.measuredPilotCleanPower];
    state.raw(packet,:)=row;state.truthBins(packet,:)=uint16(truth.');
    state.failureMessages(packet,:)=messages;
    if mod(packet,5)==0||packet==stop
        summary=savePoint(state,names,methods,directory,p,c,planned);
        fprintf('%s %s %d/%d SER %.6g %.6g %.6g ideals %.6g %.6g elapsed %.1fs\n', ...
            cohort,p.id,packet,planned,summary.precSer,summary.vpSer,summary.paperSer, ...
            summary.idealNativeSer,summary.idealPaperSer,toc(timer));
    end
end
summary=savePoint(state,names,methods,directory,p,c,planned);
end

function summary=savePoint(state,names,methods,directory,p,c,planned)
n=size(state.raw,1);assert(n>0&&isequal(state.raw(:,1),(1:n).'));
summary=struct('experimentId','normalized-k10-receiver-ser-v1','pointId',p.id, ...
    'localIndex',p.localIndex,'originalIndex',p.originalIndex,'sf',p.sf, ...
    'channel','Rician','family',p.family,'caseIndex',p.caseIndex, ...
    'snrDb',p.snrDb,'esN0Db',p.esN0Db,'orbitStartSec',p.orbitStartSec, ...
    'cohort',state.identity.cohort,'packets',n,'plannedPackets',planned, ...
    'complete',n==planned,'profileId',state.identity.profileId, ...
    'profileSha256',state.identity.profileSha256,'kDb',10, ...
    'ensembleTotalPower',1,'linkMarginDb',0,'perPacketPowerNormalization',false, ...
    'cr',3,'dataChirps',112,'noLdro',true,'nativePhysicalRows',120, ...
    'paperPhysicalRows',120+c.paperMidambleCount, ...
    'pilotInterval',c.paperMidambleInterval,'signature',state.signature, ...
    'metric','pre-FEC-FFT-hard-chirp-SER-only','berGenerated',false, ...
    'vpVersion','V8-Symbol-VP-Rolling-N8','idealRemovesFading',false, ...
    'methodIds',{methods});
for k=1:5
    name=methods{k};column=find(strcmp(names,[name 'Errors']));
    assert(isequal(sum(state.bins.(name)~=state.truthBins,2),state.raw(:,column)));
    summary.([name 'Errors'])=sum(state.raw(:,column));
    summary.([name 'Ser'])=summary.([name 'Errors'])/(112*n);
    summary.([name 'Failures'])=sum(state.raw(:,column+1));
end
temporary=fullfile(directory,'CHECKPOINT.tmp.mat');save(temporary,'state','-v7');
movefile(temporary,fullfile(directory,'CHECKPOINT.mat'),'f');
temporary=fullfile(directory,'RAW_PACKETS.tmp.csv');
writetable(array2table(state.raw,'VariableNames',names),temporary);
movefile(temporary,fullfile(directory,'RAW_PACKETS.csv'),'f');
writeText(fullfile(directory,'MANIFEST.json'),state.identityText);
writeText(fullfile(directory,'SUMMARY.json'),jsonencode(summary));
end

function requireGate(root)
gatePath=fullfile(root,'results','gate100','analysis','GATE.json');
assert(isfile(gatePath),'NkSer:GateRequired','Complete and aggregate the six-point structure gate first.');
gate=jsondecode(fileread(gatePath));
assert(gate.passed&&gate.plannedPackets==100&&gate.completePoints==6&& ...
    gate.receiverFailures==0&&gate.invalidOutputs==0, ...
    'NkSer:GateRequired','The six-point structure gate has not passed.');
current=nkserHash(jsonencode(nkserProvenance(root)),false);
assert(strcmp(gate.numericalProvenanceSha256,current), ...
    'NkSer:StaleGate','Numerical sources differ from the passed gate.');
for k=1:numel(gate.evidenceFiles)
    item=gate.evidenceFiles(k);
    assert(isfile(item.path)&&strcmp(nkserHash(item.path),item.sha256), ...
        'NkSer:StaleGateEvidence','Gate evidence changed: %s',item.path);
end
end

function writeText(file,content)
temporary=[file '.tmp'];fid=fopen(temporary,'w','n','UTF-8');assert(fid>=0);
cleanup=onCleanup(@()fclose(fid));fprintf(fid,'%s',content);clear cleanup;
movefile(temporary,file,'f');
end
