function summary=nkserRunPairedHalf(sf,options)
%NKSERRUNPAIREDHALF Independent common-random-number half-orbit diagnostic.
% Payload, taps, and semantic noise streams are identical across all five
% times for a packet. Only trajectory time and deterministic Doppler change.
arguments
    sf (1,1) double {mustBeMember(sf,[7 12])}
    options.StopAfterPackets (1,1) double {mustBePositive}=Inf
end
oldPath=path;restore=onCleanup(@()path(oldPath));roots=nkserSetup();
config=nk10Config(sf);c=config.parent;times=[-366 -274.5 -183 -91.5 0];
planned=100;seedRoot=3200000000;sfOffset=1000000*(1+(sf==12));
identity=struct('experimentId','normalized-k10-paired-half-v1','sf',sf, ...
    'timesSec',times,'esN0Db',15,'snrDb',15-10*log10(2^sf), ...
    'plannedPackets',planned,'seedRoot',seedRoot,'packetSeedBase',seedRoot+sfOffset, ...
    'packetSeedStride',8,'commonRandomNumbers',true, ...
    'onlyChangedVariables',{{'orbitStartSec','deterministic V4 orbital Doppler'}}, ...
    'profileSha256',nkserHash(roots.profilePath), ...
    'numericalProvenance',nkserProvenance(roots.root), ...
    'pairedRunnerSha256',nkserHash([mfilename('fullpath') '.m']), ...
    'receiverIdentity',roots.receiverIdentity,'metric','pre-FEC-FFT-hard-chirp-SER-only');
identityText=jsonencode(identity);signature=nkserHash(identityText,false);
directory=fullfile(roots.root,'results','pairedHalf100',sprintf('sf%d',sf));
if ~isfolder(directory),mkdir(directory);end
checkpoint=fullfile(directory,'CHECKPOINT.mat');
methods={'prec','vp','paper','idealNative','idealPaper'};
names={'packetId','timeIndex','orbitStartSec','payloadSeed','noiseSeed', ...
    'channelSeed','paperExtraNoiseSeed','noiseVariance'};
for k=1:5
    names=[names {[methods{k} 'Errors'],[methods{k} 'Failure']}]; %#ok<AGROW>
    if k<=3
        names=[names {[methods{k} 'MeanCfoBins'],[methods{k} 'MeanRateBinsPerSec']}]; %#ok<AGROW>
    end
end
names=[names {'realizedTapEnergy'}];
if isfile(checkpoint)
    loaded=load(checkpoint,'state');state=loaded.state;
    assert(strcmp(state.signature,signature)&&strcmp(state.identityText,identityText), ...
        'NkSer:PairedIdentity','Paired diagnostic identity changed.');
else
    state=struct('signature',signature,'identity',identity,'identityText',identityText, ...
        'raw',zeros(0,numel(names)),'failureMessages',strings(0,5));
end
assert(mod(size(state.raw,1),5)==0,'NkSer:PairedContinuity','Incomplete five-time group.');
completed=size(state.raw,1)/5;stop=min(planned,options.StopAfterPackets);
for packet=completed+1:stop
    seed=identity.packetSeedBase+packet*8;
    seeds=struct('payloadSeed',seed,'noiseSeed',seed+1, ...
        'channelSeed',seed+2,'paperExtraNoiseSeed',seed+3);
    referenceTruth=[];referenceTaps=[];
    for timeIndex=1:5
        pair=nk10GeneratePair(config,times(timeIndex),identity.snrDb,seeds);
        if timeIndex==1
            referenceTruth=pair.native.truth.payloadPhysicalBins(:);
            referenceTaps=pair.native.truth.channelTaps;
        else
            assert(isequal(referenceTruth,pair.native.truth.payloadPhysicalBins(:))&& ...
                isequal(referenceTaps,pair.native.truth.channelTaps), ...
                'NkSer:Pairing','Payload or channel taps changed across paired times.');
        end
        actual=acDecodeMethods(pair,config);truth=referenceTruth;
        row=[packet timeIndex times(timeIndex) seed seed+1 seed+2 seed+3 pair.power.noiseVariance];
        messages=strings(1,5);keys={'PREC','VP','Paper'};
        for k=1:5
            failed=false;message="";meanCfo=NaN;meanRate=NaN;
            if k<=3
                failed=actual.failures.(keys{k});message=actual.messages.(keys{k});
                if failed
                    bins=repmat(65535,112,1);
                else
                    result=actual.(keys{k});bins=result.detectedPhysicalBins(:);
                    meanCfo=mean(result.estimatedCfoBins);
                    meanRate=mean(result.estimatedRateBinsPerSec);
                end
            else
                if k==4
                    frame=pair.nativeIdeal;layout=pair.native.observation.layout;
                else
                    frame=pair.pilotIdeal;layout=pair.pilot.observation.layout;
                end
                try
                    result=prefecNativeHardDetect(frame.rxPhysical(layout.dataRows,:),c);
                    bins=result.detectedPhysicalBins(:);
                catch problem
                    failed=true;message=string(problem.identifier)+": "+string(problem.message);
                    bins=repmat(65535,112,1);
                end
            end
            errors=nnz(bins~=truth);
            if failed,assert(errors==112);end
            row=[row errors double(failed)]; %#ok<AGROW>
            if k<=3,row=[row meanCfo meanRate];end %#ok<AGROW>
            messages(k)=message;
        end
        row=[row pair.power.realizedTapEnergy];
        state.raw(end+1,:)=row;state.failureMessages(end+1,:)=messages; %#ok<AGROW>
    end
    if mod(packet,5)==0||packet==stop
        summary=savePaired(state,names,methods,directory,times,planned,sf);
        fprintf('pairedHalf100 sf%d %d/%d\n',sf,packet,planned);
    end
end
summary=savePaired(state,names,methods,directory,times,planned,sf);
end

function summary=savePaired(state,names,methods,directory,times,planned,sf)
n=size(state.raw,1)/5;assert(n==fix(n)&&n>0);
summary=struct('experimentId','normalized-k10-paired-half-v1','sf',sf, ...
    'packetsPerTime',n,'plannedPacketsPerTime',planned,'complete',n==planned, ...
    'timesSec',times,'methodIds',{methods},'metric','pre-FEC-FFT-hard-chirp-SER-only', ...
    'commonRandomNumbers',true,'berGenerated',false,'signature',state.signature);
for k=1:5
    name=methods{k};errorColumn=find(strcmp(names,[name 'Errors']));
    failureColumn=find(strcmp(names,[name 'Failure']));
    errors=zeros(1,5);failures=zeros(1,5);
    for t=1:5
        selected=state.raw(:,2)==t;
        errors(t)=sum(state.raw(selected,errorColumn));
        failures(t)=sum(state.raw(selected,failureColumn));
    end
    summary.([name 'ErrorsByTime'])=errors;
    summary.([name 'SerByTime'])=errors/(112*n);
    summary.([name 'FailuresByTime'])=failures;
end
temporary=fullfile(directory,'CHECKPOINT.tmp.mat');save(temporary,'state','-v7');
movefile(temporary,fullfile(directory,'CHECKPOINT.mat'),'f');
temporary=fullfile(directory,'RAW_PAIRED.tmp.csv');
writetable(array2table(state.raw,'VariableNames',names),temporary);
movefile(temporary,fullfile(directory,'RAW_PAIRED.csv'),'f');
writeText(fullfile(directory,'MANIFEST.json'),state.identityText);
writeText(fullfile(directory,'SUMMARY.json'),jsonencode(summary));
end

function writeText(file,content)
temporary=[file '.tmp'];fid=fopen(temporary,'w','n','UTF-8');assert(fid>=0);
cleanup=onCleanup(@()fclose(fid));fprintf(fid,'%s',content);clear cleanup;
movefile(temporary,file,'f');
end
