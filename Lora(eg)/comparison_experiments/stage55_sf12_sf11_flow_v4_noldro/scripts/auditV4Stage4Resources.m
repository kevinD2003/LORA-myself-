function audit=auditV4Stage4Resources()
root=v4SetupPaths();compact=jsondecode(fileread(fullfile(root,'results','stage3s','reports','RUN_COST_ESTIMATE_A_R5_COMPACT.json')));legacy=jsondecode(fileread(fullfile(root,'results','stage3s','reports','RUN_COST_ESTIMATE_A_R5.json')));
[~,systemMemory]=memory;workerCount=2;estimatedWorkerBytes=legacy.peakMatlabMemoryBytes;memoryPassed=(workerCount+1)*estimatedWorkerBytes<=0.70*systemMemory.PhysicalMemory.Total;
passed=compact.storageGatePassed&&memoryPassed;
audit=struct('stage','STAGE_04_RESOURCE_AUDIT','overall',status(passed),'formalPackets',400000,'workerCount',workerCount,'singleProcessPeakBytes',estimatedWorkerBytes,'estimatedTotalProcessBytes',(workerCount+1)*estimatedWorkerBytes,'seventyPercentPhysicalBytes',0.70*systemMemory.PhysicalMemory.Total,'memoryGate',status(memoryPassed),'compactStorageGate',status(compact.storageGatePassed),'conservativeStorageGiB',compact.conservativeStorageGiB,'availableFreeGiB',compact.availableFreeGiB,'conservativeSerialRuntimeHours',legacy.conservativeRuntimeHours,'expectedTwoWorkerRuntimeHours',legacy.conservativeRuntimeHours/2,'admission',ternary(passed,'ADMIT_STAGE_4_FORMAL','DO_NOT_ADMIT_STAGE_4_FORMAL'));
folder=fullfile(root,'results','formal','track_a','R5-point-anchored');if ~isfolder(folder),mkdir(folder);end;write(fullfile(folder,'STAGE_04_RESOURCE_AUDIT.json'),jsonencode(audit,'PrettyPrint',true));write(fullfile(folder,'STAGE_04_RESOURCE_AUDIT.md'),sprintf('# Stage 4 resource audit\n\nOverall `%s`; storage `%s`; memory `%s`; workers %d.\n',audit.overall,audit.compactStorageGate,audit.memoryGate,workerCount));if ~passed,error('V4:Stage4Resources','Resource gate failed.');end
end
function x=status(ok),if ok,x='PASS';else,x='FAIL';end,end
function x=ternary(ok,a,b),if ok,x=a;else,x=b;end,end
function write(path,text),f=fopen(path,'w','n','UTF-8');c=onCleanup(@()fclose(f));fprintf(f,'%s\n',text);clear c,end
