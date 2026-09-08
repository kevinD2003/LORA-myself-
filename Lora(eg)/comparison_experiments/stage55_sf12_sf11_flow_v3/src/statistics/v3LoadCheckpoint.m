function state = v3LoadCheckpoint(path,expectedSignature)
%V3LOADCHECKPOINT Refuse resume when code/config/seed signature changes.

saved = load(path,'state','signature');
if ~isfield(saved,'signature') || ~strcmp(saved.signature,expectedSignature)
    error('V3:CheckpointSignature','Checkpoint signature mismatch.');
end
state = saved.state;
end

