function audit=auditV4Stage3RCalibrationRound(roundNumber)
root=v4SetupPaths();[~,metadata]=v4Stage3RCandidateTable(root,roundNumber);
folder=fullfile(root,'results','stage3r','Stage55-A-causal-pending-lock-v1', ...
    metadata.parameterVersion,'calibration');path=fullfile(folder,'stage3r_calibration.json');
artifact=jsondecode(fileread(path));records=artifact.records;recalculated=true;
for i=1:numel(records)
    cases={records(i).caseMinus366,records(i).case0};
    for k=1:2
        x=cases{k}; expectedCoverage=x.accepted/x.possible;
        if x.accepted>0,expectedFa=x.falseAccepted/x.accepted;else,expectedFa=NaN;end
        recalculated=recalculated && abs(x.coverage-expectedCoverage)<1e-12 && ...
            ((isnan(expectedFa)&&isnan(x.falseAcceptance))||abs(x.falseAcceptance-expectedFa)<1e-12);
    end
end
passed=strcmp(artifact.status,'PASS')&&recalculated;
if roundNumber==1 && ~passed,admission='ADMIT_CALIBRATION_ROUND_2';
elseif passed,admission=sprintf('ADMIT_VALIDATION_V%d',roundNumber);
else,admission='DO_NOT_ADMIT_FURTHER_CALIBRATION';end
audit=struct('stage',sprintf('STAGE_03R_CALIBRATION_V%d_AUDIT',roundNumber), ...
    'overall',artifact.status,'recalculation',status(recalculated), ...
    'artifactHash',v4Sha256(path),'algorithmSignature',artifact.algorithmSignature, ...
    'candidateTableHash',artifact.candidateTableHash,'candidateCount',numel(records), ...
    'packetsPerCandidateCase',artifact.calibrationPacketsPerCandidateCase, ...
    'selectedCandidateIndex',artifact.selectedCandidateIndex, ...
    'admission',admission,'nextRoundPreRegistered',roundNumber==1);
auditFolder=fullfile(root,'results','stage3r','audits');
localWrite(fullfile(auditFolder,[audit.stage '.json']),jsonencode(audit,'PrettyPrint',true));
localWrite(fullfile(auditFolder,[audit.stage '.md']),sprintf(['# Stage 3R calibration round %d audit\n\n' ...
    'Overall: `%s`. Recalculation: `%s`. Admission: `%s`.\n\nArtifact SHA-256: `%s`.\n'], ...
    roundNumber,audit.overall,audit.recalculation,audit.admission,audit.artifactHash));
if ~recalculated,error('V4:Stage3RCalibrationAudit','Calibration recount failed.');end
end
function value=status(ok),if ok,value='PASS';else,value='FAIL';end,end
function localWrite(path,text),f=fopen(path,'w','n','UTF-8');c=onCleanup(@()fclose(f));fprintf(f,'%s\n',text);clear c,end
