function audit=auditV4Stage3SMechanism()
root=v4SetupPaths();r=runV4Stage3SMechanismTests();s=v4VerifyReadOnlySources(root);oldOk=localOld(root);
passed=all([r.Passed])&&s.passed&&oldOk;audit=struct('stage','STAGE_03S_02_MECHANISM_AUDIT', ...
    'overall',status(passed),'planSha256',v4Sha256(fullfile(root,'SF12无LDRO双轨完整实验V4方案_R5_STAGE3S.md')), ...
    'testNames',{string({r.Name})},'testPassed',[r.Passed],'sourceBoundary',status(s.passed), ...
    'r3R4Evidence',status(oldOk),'calibration','NOT_APPLICABLE','validation','NOT_APPLICABLE', ...
    'admission',ternary(passed,'ADMIT_STAGE_03S_CALIBRATION','DO_NOT_ADMIT_STAGE_03S_CALIBRATION'));
folder=fullfile(root,'results','stage3s','audits');write(fullfile(folder,'STAGE_03S_02_MECHANISM_AUDIT.json'),jsonencode(audit,'PrettyPrint',true));
write(fullfile(folder,'STAGE_03S_02_MECHANISM_AUDIT.md'),sprintf('# Stage 3S-02 mechanism audit\n\nOverall: `%s`; 18 tests executed. Admission: `%s`.\n',audit.overall,audit.admission));
if ~passed,error('V4:Stage3SMechanismAudit','Stage3S mechanism audit failed.');end
end
function ok=localOld(root),ok=true;for name={'r3_failure_evidence_manifest.json','r4_failure_evidence_manifest.json'},m=jsondecode(fileread(fullfile(root,'config',name{1})));for i=1:numel(m.files),ok=ok&&strcmp(v4Sha256(fullfile(root,m.files(i).path)),m.files(i).sha256);end,end,end
function x=status(ok),if ok,x='PASS';else,x='FAIL';end,end
function x=ternary(ok,a,b),if ok,x=a;else,x=b;end,end
function write(path,text),f=fopen(path,'w','n','UTF-8');c=onCleanup(@()fclose(f));fprintf(f,'%s\n',text);clear c,end
