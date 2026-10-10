function report = exp1ValidateFrozenParent(config)
%EXP1VALIDATEFROZENPARENT Verify the G0 source lock before every run.

manifest = jsondecode(fileread(config.parentManifestPath));
entries = manifest.files;
if ~isstruct(entries)
    error('EXP1:ParentManifest','Parent manifest file list is invalid.');
end
actual = strings(numel(entries),1);
valid = false(numel(entries),1);
for index = 1:numel(entries)
    relativePath = strrep(entries(index).path,'/',filesep);
    path = fullfile(config.parentRoot,relativePath);
    if ~isfile(path)
        error('EXP1:ParentSourceMissing','Frozen parent file is missing: %s',path);
    end
    actual(index) = exp1Sha256(path);
    valid(index) = strcmpi(actual(index),entries(index).sha256);
end
manifestPaths = string({entries.path}).';
entry = which('exp1RunCell');
required = matlab.codetools.requiredFilesAndProducts(entry);
required = string(required(:));
required = required(startsWith(required,string(config.parentRoot), ...
    'IgnoreCase',true));
requiredRelative = erase(required,string(config.parentRoot)+filesep);
requiredRelative = replace(requiredRelative,filesep,'/');
missing = setdiff(requiredRelative,manifestPaths);
if ~isempty(missing)
    error('EXP1:ParentDependencyUnlocked', ...
        'Runtime parent dependencies are not locked:\n%s', ...
        strjoin(cellstr(missing),newline));
end
if ~all(valid)
    failed = find(~valid);
    messages = strings(numel(failed),1);
    for row = 1:numel(failed)
        index = failed(row);
        messages(row) = sprintf('%s expected %s actual %s', ...
            entries(index).path,entries(index).sha256,actual(index));
    end
    error('EXP1:ParentSourceDrift','Frozen parent hash mismatch:\n%s', ...
        strjoin(cellstr(messages),newline));
end
report = struct('status','PASS','manifestVersion',manifest.manifestVersion, ...
    'parentBaseGitCommit',manifest.parentBaseGitCommit, ...
    'sourceState',manifest.sourceState,'fileCount',numel(entries), ...
    'runtimeDependencyCount',numel(requiredRelative), ...
    'manifestSha256',exp1Sha256(config.parentManifestPath));
end
