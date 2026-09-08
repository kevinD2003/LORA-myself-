function v4WriteAuditEvidence(root,stageId,audit)
%V4WRITEAUDITEVIDENCE Write paired machine-readable and Markdown audit files.
folder = fullfile(root,'results','audits');
if ~isfolder(folder), mkdir(folder); end
stem = upper(string(stageId));
jsonPath = fullfile(folder,char(stem+".json"));
mdPath = fullfile(folder,char(stem+".md"));
localWrite(jsonPath,jsonencode(audit,'PrettyPrint',true));
lines = ["# "+stem; ""; "Overall: `"+string(audit.overall)+"`."; ""; ...
    "Evidence JSON: `"+string(jsonPath)+"`."; ""; ...
    "Tests passing is necessary but does not replace this audit."];
localWrite(mdPath,strjoin(lines,newline));
end

function localWrite(path,text)
file = fopen(path,'w','n','UTF-8');
if file < 0, error('V4:AuditWrite','Cannot write %s.',path); end
cleanup = onCleanup(@()fclose(file));
fprintf(file,'%s\n',text);
clear cleanup
end
