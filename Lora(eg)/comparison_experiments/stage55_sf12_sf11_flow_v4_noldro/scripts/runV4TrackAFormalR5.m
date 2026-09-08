function result=runV4TrackAFormalR5(options)
arguments,options.UseParallel (1,1) logical=true,options.WorkerCount (1,1) double {mustBeInteger,mustBePositive}=2,end
root=v4SetupPaths();config=sf12NoLdroSf11FlowConfig();m=jsondecode(fileread(fullfile(root,'config','paperReceiverParameterManifest_stage3s_v01.json')));if ~strcmp(m.status,'frozen-stage3s'),error('V4:FormalAdmission','Stage3S parameters are not smoke-frozen.');end
audit=jsondecode(fileread(fullfile(root,'results','stage3s','audits','STAGE_03S_EXPERIMENT_A_CORRECTION_AUDIT.json')));if ~strcmp(audit.overall,'PASS')||~strcmp(audit.admission,'ADMIT_STAGE_4'),error('V4:FormalAdmission','Stage3S audit does not admit Stage4.');end
storage=jsondecode(fileread(fullfile(root,'results','stage3s','reports','RUN_COST_ESTIMATE_A_R5_COMPACT.json')));if ~storage.storageGatePassed,error('V4:FormalStorage','Compact storage gate failed.');end
cells=cell(20,1);
if options.UseParallel
    pool=gcp('nocreate');if isempty(pool)||pool.NumWorkers~=options.WorkerCount,if ~isempty(pool),delete(pool);end;pool=parpool('local',options.WorkerCount);end %#ok<NASGU>
    parfor index=1:20
        caseIndex=ceil(index/10);snrIndex=mod(index-1,10)+1;
        cells{index}=v4RunTrackAFormalCellR5(root,config,m.parameters,m.algorithmSignature,caseIndex,snrIndex);
    end
else
    for index=1:20,caseIndex=ceil(index/10);snrIndex=mod(index-1,10)+1;cells{index}=v4RunTrackAFormalCellR5(root,config,m.parameters,m.algorithmSignature,caseIndex,snrIndex);end
end
result=struct('status','PASS','planVersion','V4-noLDRO-plan-R5-track-a-point-anchored-lock','algorithmSignature',m.algorithmSignature,'cellCount',20,'fixedPacketsPerCell',20000,'totalPairedPackets',400000,'cells',{cells});
folder=fullfile(root,'results','formal','track_a','R5-point-anchored');save(fullfile(folder,'formal_index.mat'),'result','-v7.3');
end
