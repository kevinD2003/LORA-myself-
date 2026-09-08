function result = v4VerifyReadOnlySources(root)
%V4VERIFYREADONLYSOURCES Verify the canonical source and its frozen snapshot.
raw = fileread(fullfile(root,'config','source_manifest.json'));
manifest = jsondecode(raw);
pairs = regexp(raw,'"([^"]+\.m)"\s*:\s*"([0-9a-f]{64})"','tokens');
names = cellfun(@(x)x{1},pairs,'UniformOutput',false);
hashes = cellfun(@(x)x{2},pairs,'UniformOutput',false);
canonicalOk = true(numel(names),1);
snapshotOk = true(numel(names),1);
for index = 1:numel(names)
    name = names{index};
    expected = hashes{index};
    canonicalOk(index) = strcmp(v4Sha256(fullfile(manifest.canonicalRoot,name)),expected);
    snapshotOk(index) = strcmp(v4Sha256(fullfile(root,manifest.snapshotRoot,name)),expected);
end
result = struct('fileCount',numel(names),'canonicalOk',canonicalOk, ...
    'snapshotOk',snapshotOk,'passed',all(canonicalOk & snapshotOk));
end
