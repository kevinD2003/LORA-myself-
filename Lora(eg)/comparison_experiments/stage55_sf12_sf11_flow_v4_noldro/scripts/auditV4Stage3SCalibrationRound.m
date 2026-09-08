function audit=auditV4Stage3SCalibrationRound(roundNumber)
root=v4SetupPaths();[~,meta]=v4Stage3SCandidateTable(root,roundNumber);folder=fullfile(root,'results','stage3s','Stage55-A-point-anchored-provisional-lock-v2',meta.parameterVersion,'calibration');path=fullfile(folder,'stage3s_calibration.json');a=jsondecode(fileread(path));ok=true;
for i=1:numel(a.records),for field={'caseMinus366','case0'},x=a.records(i).(field{1});ok=ok&&abs(x.coverage-x.accepted/x.possible)<1e-12;if x.accepted>0,ok=ok&&abs(x.falseAcceptance-x.falseAccepted/x.accepted)<1e-12;else,ok=ok&&isnan(x.falseAcceptance);end,end,end
if strcmp(a.status,'PASS'),admission=sprintf('ADMIT_STAGE_03S_VALIDATION_V%d',roundNumber);elseif roundNumber==1,admission='ADMIT_STAGE_03S_CALIBRATION_V2';else,admission='DO_NOT_ADMIT_FURTHER_CALIBRATION';end
audit=struct('stage',sprintf('STAGE_03S_CALIBRATION_V%d_AUDIT',roundNumber),'overall',a.status,'recalculation',status(ok),'artifactHash',v4Sha256(path),'algorithmSignature',a.algorithmSignature,'candidateTableHash',a.candidateTableHash,'candidateCount',numel(a.records),'packetsPerCandidateCase',a.calibrationPacketsPerCandidateCase,'selectedCandidateIndex',a.selectedCandidateIndex,'admission',admission);
out=fullfile(root,'results','stage3s','audits');write(fullfile(out,[audit.stage '.json']),jsonencode(audit,'PrettyPrint',true));write(fullfile(out,[audit.stage '.md']),sprintf('# Stage 3S calibration v%d audit\n\nOverall: `%s`; recount `%s`; admission `%s`.\n',roundNumber,audit.overall,audit.recalculation,audit.admission));if ~ok,error('V4:Stage3SCalibrationAudit','Recalculation failed.');end
end
function x=status(ok),if ok,x='PASS';else,x='FAIL';end,end
function write(path,text),f=fopen(path,'w','n','UTF-8');c=onCleanup(@()fclose(f));fprintf(f,'%s\n',text);clear c,end
