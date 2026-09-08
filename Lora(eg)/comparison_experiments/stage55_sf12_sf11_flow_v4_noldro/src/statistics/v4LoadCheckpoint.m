function state = v4LoadCheckpoint(path,expectedSignature)
%V4LOADCHECKPOINT Refuse resume when code/config/seed signature changes.

saved = load(path,'state','signature');
if ~isfield(saved,'signature') || ~strcmp(saved.signature,expectedSignature)
    error('V4:CheckpointSignature','Checkpoint signature mismatch.');
end
state = saved.state;
end

