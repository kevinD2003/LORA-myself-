function repair=repairV4Stage3SSelectedSignature(roundNumber)
% Repair manifest-only signature split; never rewrite calibration evidence.
root=v4SetupPaths();[candidates,meta]=v4Stage3SCandidateTable(root,roundNumber);
calibrationPath=fullfile(root,'results','stage3s','Stage55-A-point-anchored-provisional-lock-v2',meta.parameterVersion,'calibration','stage3s_calibration.json');
beforeHash=v4Sha256(calibrationPath);a=jsondecode(fileread(calibrationPath));
if ~strcmp(a.status,'PASS')||~isfinite(a.selectedCandidateIndex),error('V4:SignatureRepair','No selected calibration candidate.');end
manifestPath=fullfile(root,'config',sprintf('paperReceiverParameterManifest_stage3s_v%02d.json',roundNumber));m=jsondecode(fileread(manifestPath));
selected=candidates(a.selectedCandidateIndex);selectedSignature=v4Stage3SSignature(root,selected,meta.hash);
m.calibrationSignature=a.algorithmSignature;m.algorithmSignature=selectedSignature;m.parameters=selected;
write(manifestPath,jsonencode(m,'PrettyPrint',true));afterHash=v4Sha256(calibrationPath);
if ~strcmp(beforeHash,afterHash),error('V4:SignatureRepair','Calibration evidence changed during repair.');end
repair=struct('status','PASS','issue','Candidate-set signature was stored as selected-run signature.', ...
    'calibrationArtifactHashBefore',beforeHash,'calibrationArtifactHashAfter',afterHash, ...
    'calibrationSignature',a.algorithmSignature,'selectedAlgorithmSignature',selectedSignature, ...
    'selectedCandidateIndex',a.selectedCandidateIndex,'affectedResults','none; validation had processed zero packets');
folder=fullfile(root,'results','stage3s','audits');write(fullfile(folder,'STAGE_03S_SIGNATURE_REPAIR_AUDIT.json'),jsonencode(repair,'PrettyPrint',true));
write(fullfile(folder,'STAGE_03S_SIGNATURE_REPAIR_AUDIT.md'),sprintf('# Stage 3S signature repair audit\n\nStatus: `PASS`. Calibration artifact remained `%s`; validation processed zero packets before rejection.\n',beforeHash));
end
function write(path,text),f=fopen(path,'w','n','UTF-8');c=onCleanup(@()fclose(f));fprintf(f,'%s\n',text);clear c,end
