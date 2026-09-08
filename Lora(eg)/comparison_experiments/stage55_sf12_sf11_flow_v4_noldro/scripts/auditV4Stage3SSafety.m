function audit=auditV4Stage3SSafety(roundNumber)
root=v4SetupPaths();[~,meta]=v4Stage3SCandidateTable(root,roundNumber);path=fullfile(root,'results','stage3s','Stage55-A-point-anchored-provisional-lock-v2',meta.parameterVersion,'safety','stage3s_safety.json');a=jsondecode(fileread(path));audit=struct('stage','STAGE_03S_SAFETY_AUDIT','overall',a.status,'artifactHash',v4Sha256(path),'records',a.records,'admission',ternary(strcmp(a.status,'PASS'),'ADMIT_STAGE_03S_SMOKE','DO_NOT_ADMIT_STAGE_03S_SMOKE'));out=fullfile(root,'results','stage3s','audits');write(fullfile(out,'STAGE_03S_SAFETY_AUDIT.json'),jsonencode(audit,'PrettyPrint',true));write(fullfile(out,'STAGE_03S_SAFETY_AUDIT.md'),sprintf('# Stage 3S safety audit\n\nOverall: `%s`; admission `%s`.\n',audit.overall,audit.admission));
end
function x=ternary(ok,a,b),if ok,x=a;else,x=b;end,end
function write(path,text),f=fopen(path,'w','n','UTF-8');c=onCleanup(@()fclose(f));fprintf(f,'%s\n',text);clear c,end
