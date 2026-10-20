function summary=runAcPoint(index,cohort,options)
%RUNACPOINT Independent paired all-curve hard-SER experiment, resumable.
arguments
    index (1,1) double {mustBeInteger,mustBeInRange(index,1,100)}
    cohort (1,1) string {mustBeMember(cohort,["smoke","validation100","formal1000"])}="validation100"
    options.StopAfterPackets (1,1) double {mustBePositive}=Inf
end
oldPath=path;restore=onCleanup(@()path(oldPath));roots=acSetup();
[points,configs]=acProjectConditions();p=points(index);config=configs{1+(p.sf==12)};c=config.parent;
if cohort=="smoke",planned=2;seedRoot=2690000000;
elseif cohort=="validation100",planned=100;seedRoot=2700000000;
else,planned=1000;seedRoot=2800000000;requireValidation(roots.root);end
identity=struct('pointId',p.id,'point',p,'config',config,'cohort',cohort, ...
    'plannedPackets',planned,'seedRoot',seedRoot,'packetSeedBase',seedRoot+index*100000, ...
    'packetSeedStride',8,'globalKDb',10,'profileIndex',5, ...
    'profileSha256',acHash(jsonencode(config.channelProfile),false), ...
    'codeProvenance',acProvenance(roots.root),'matlabVersion',version, ...
    'receiverIdentity',roots.receiverIdentity,'vpHistoryLength',8, ...
    'symbolSource','native-FFT-hard-chirp-before-FEC', ...
    'bitErrorStage','hard-FEC-decoded-information-bits', ...
    'idealPolicy','exact-common-Doppler-removal-fading-and-ISI-retained');
identityText=jsonencode(identity);signature=acHash(identityText,false);
directory=fullfile(roots.root,'results',char(cohort),p.id);if ~isfolder(directory),mkdir(directory);end
file=fullfile(directory,'CHECKPOINT.mat');
methods={'prec','vp','paper','idealNative','idealPaper'};
names={'packetId','payloadSeed','noiseSeed','channelSeed','paperExtraNoiseSeed','noiseVariance'};
for k=1:numel(methods)
    name=methods{k};names=[names {[name 'Errors'],[name 'Failure'],[name 'BitErrors'],[name 'DecodeFailure']}]; %#ok<AGROW>
end
names=[names {'runtimeCommonSec','runtimePrecSec','runtimeVpSec','runtimePaperSec', ...
    'vpAcceptedSymbols','vpUsedSymbols','vpRateUpdates','noisePowerEstimate', ...
    'channelPower','nativeCleanPower','paperCleanPower'}];
if isfile(file)
    loaded=load(file,'state');state=loaded.state;
    assert(strcmp(state.signature,signature),'Ac:Signature','Sources/configuration changed; cannot pool checkpoint.');
    assert(strcmp(state.identityText,identityText),'Ac:Identity','Manifest mismatch.');
else
    state=struct('signature',signature,'identity',identity,'identityText',identityText, ...
        'raw',zeros(0,numel(names)),'truthBins',zeros(0,112,'uint16'), ...
        'bins',struct(),'failureMessages',strings(0,5));
    for k=1:5,state.bins.(methods{k})=zeros(0,112,'uint16');end
end
assert(isequal(state.raw(:,1),(1:size(state.raw,1)).'),'Ac:Continuity','Packet gap.');
stop=min(planned,options.StopAfterPackets);timer=tic;
for packet=size(state.raw,1)+1:stop
    seed=identity.packetSeedBase+packet*8;
    seeds=struct('payloadSeed',seed,'noiseSeed',seed+1,'channelSeed',seed+2,'paperExtraNoiseSeed',seed+3);
    pair=acGeneratePair(config,p.orbitStartSec,p.snrDb,string(p.channel),seeds);
    actual=acDecodeMethods(pair,config);
    % Offline truth/evaluation begins after all real receivers have returned.
    truth=pair.native.truth.payloadPhysicalBins(:);truthBits=pair.native.truth.dataBits;
    assert(isequal(truth,pair.pilot.truth.payloadPhysicalBins(:)));
    row=[packet seed seed+1 seed+2 seed+3 pair.power.noiseVariance];messages=strings(1,5);
    keys={'PREC','VP','Paper'};
    for k=1:5
        failed=false;message="";bitFailure=false;bitErrors=c.informationBitCount;
        if k<=3
            failed=actual.failures.(keys{k});message=actual.messages.(keys{k});
            if failed,bins=repmat(65535,112,1);else,bins=actual.(keys{k}).detectedPhysicalBins(:);end
        else
            if k==4,frame=pair.nativeIdeal;layout=pair.native.observation.layout;
            else,frame=pair.pilotIdeal;layout=pair.pilot.observation.layout;end
            try
                ideal=prefecNativeHardDetect(frame.rxPhysical(layout.dataRows,:),c);
                bins=ideal.detectedPhysicalBins(:);
            catch problem
                failed=true;message=string(problem.identifier)+": "+string(problem.message);bins=repmat(65535,112,1);
            end
        end
        errors=nnz(bins~=truth);if failed,assert(errors==112);bitFailure=true;
        else
            try
                bits=acHardBits(bins,c);assert(isequal(size(bits),size(truthBits)));
                bitErrors=nnz(bits~=truthBits);
            catch problem
                bitFailure=true;message=message+" hardFEC: "+string(problem.message);
            end
        end
        row=[row errors double(failed) bitErrors double(bitFailure)]; %#ok<AGROW>
        state.bins.(methods{k})(packet,:)=uint16(bins.');messages(k)=message;
    end
    accepted=NaN;used=NaN;rateUpdates=NaN;
    if ~actual.failures.VP
        accepted=actual.VP.acceptedVirtualPilots;used=actual.VP.usedVirtualPilots;
        rateUpdates=sum(actual.VP.fitLog.rateUpdated);
    end
    rt=actual.runtimeSec;
    row=[row rt.common rt.PREC rt.VP rt.Paper accepted used rateUpdates actual.noisePowerEstimate ...
        pair.power.channelPower pair.power.measuredNativeCleanPower pair.power.measuredPilotCleanPower];
    state.raw(packet,:)=row;state.truthBins(packet,:)=uint16(truth.');state.failureMessages(packet,:)=messages;
    if mod(packet,5)==0 || packet==stop
        summary=savePoint(state,names,methods,directory,p,c,planned);
        fprintf('%s %s %d/%d SER %.6g %.6g %.6g ideal %.6g %.6g elapsed %.1fs\n', ...
            cohort,p.id,packet,planned,summary.precSer,summary.vpSer,summary.paperSer, ...
            summary.idealNativeSer,summary.idealPaperSer,toc(timer));
    end
end
summary=savePoint(state,names,methods,directory,p,c,planned);
end

function summary=savePoint(state,names,methods,directory,p,c,planned)
n=size(state.raw,1);assert(n>0 && isequal(state.raw(:,1),(1:n).'));
summary=struct('pointId',p.id,'index',p.index,'sf',p.sf,'channel',p.channel, ...
    'family',p.family,'caseIndex',p.caseIndex,'snrDb',p.snrDb,'esN0Db',p.esN0Db, ...
    'orbitStartSec',p.orbitStartSec,'cohort',state.identity.cohort, ...
    'packets',n,'plannedPackets',planned,'complete',n==planned,'globalKDb',10, ...
    'profileIndex',5,'profileSha256',state.identity.profileSha256, ...
    'cr',3,'dataChirps',112,'informationBits',c.informationBitCount,'noLdro',true, ...
    'nativePhysicalRows',120,'paperPhysicalRows',120+c.paperMidambleCount, ...
    'pilotInterval',c.paperMidambleInterval,'signature',state.signature, ...
    'symbolSource','native-FFT-hard-chirp-before-FEC', ...
    'bitErrorStage','hard-FEC-decoded-information-bits', ...
    'vpVersion','V8-Symbol-VP-Rolling-N8','idealRemovesFading',false, ...
    'perPacketPowerNormalization',false,'paperPdpMatched',false);
summary.methodIds=methods;
for k=1:5
    name=methods{k};column=find(strcmp(names,[name 'Errors']));
    assert(isequal(sum(state.bins.(name)~=state.truthBins,2),state.raw(:,column)));
    summary.([name 'Errors'])=sum(state.raw(:,column));
    summary.([name 'Ser'])=summary.([name 'Errors'])/(112*n);
    summary.([name 'Failures'])=sum(state.raw(:,column+1));
    summary.([name 'BitErrors'])=sum(state.raw(:,column+2));
    summary.([name 'Ber'])=summary.([name 'BitErrors'])/(c.informationBitCount*n);
    summary.([name 'DecodeFailures'])=sum(state.raw(:,column+3));
end
save(fullfile(directory,'CHECKPOINT.tmp.mat'),'state','-v7');
movefile(fullfile(directory,'CHECKPOINT.tmp.mat'),fullfile(directory,'CHECKPOINT.mat'),'f');
tmp=fullfile(directory,'RAW_PACKETS.tmp.csv');writetable(array2table(state.raw,'VariableNames',names),tmp);
movefile(tmp,fullfile(directory,'RAW_PACKETS.csv'),'f');
writeText(fullfile(directory,'MANIFEST.json'),state.identityText);
writeText(fullfile(directory,'SUMMARY.json'),jsonencode(summary));
end

function writeText(file,content)
tmp=[file '.tmp'];fid=fopen(tmp,'w','n','UTF-8');assert(fid>=0);cleanup=onCleanup(@()fclose(fid));
fprintf(fid,'%s',content);clear cleanup;movefile(tmp,file,'f');
end

function requireValidation(root)
gate=fullfile(root,'results','validation100','analysis','VALIDATION_GATE.json');
assert(isfile(gate),'Ac:ValidationRequired','Complete 100-packet validation first.');
value=jsondecode(fileread(gate));assert(value.passed && value.plannedPackets==100 && ...
    value.completePoints==100,'Ac:ValidationRequired','100-packet coverage/failure/source checks must pass.');
assert(strcmp(jsonencode(value.codeProvenance),jsonencode(acProvenance(root))), ...
    'Ac:StaleGate','Validation code differs from current source.');
evidence=fullfile(root,'results','validation100','analysis','AGGREGATE_MANIFEST.json');
assert(isfile(evidence) && strcmp(acHash(evidence),value.aggregateManifestSha256), ...
    'Ac:StaleGate','Validation aggregate evidence changed.');
manifest=jsondecode(fileread(evidence));
assert(isfield(manifest,'files'),'Ac:EvidenceSchema','Missing evidence file hashes.');
for k=1:numel(manifest.files)
    item=manifest.files(k);
    assert(isfile(item.path) && strcmp(acHash(item.path),item.sha256), ...
        'Ac:StaleEvidence','Validation file changed: %s',item.path);
end
end
