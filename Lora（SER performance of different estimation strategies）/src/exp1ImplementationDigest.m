function report = exp1ImplementationDigest(config)
%EXP1IMPLEMENTATIONDIGEST Hash all executable EXP1 configuration and code.

folders = {'configs','src','scripts'};
paths = strings(0,1);
for folderIndex = 1:numel(folders)
    entries = dir(fullfile(config.projectRoot,folders{folderIndex},'*.m'));
    for entryIndex = 1:numel(entries)
        paths(end+1,1) = string(fullfile(entries(entryIndex).folder, ...
            entries(entryIndex).name)); %#ok<AGROW>
    end
end
paths = sort(paths);
lines = strings(numel(paths),1);
relativePaths = strings(numel(paths),1);
hashes = strings(numel(paths),1);
for index = 1:numel(paths)
    relativePaths(index) = erase(paths(index),string(config.projectRoot)+filesep);
    relativePaths(index) = replace(relativePaths(index),filesep,'/');
    hashes(index) = exp1Sha256(paths(index));
    lines(index) = relativePaths(index)+"="+hashes(index);
end
report = struct('sha256',exp1Sha256(strjoin(lines,newline)), ...
    'fileCount',numel(paths),'relativePaths',relativePaths, ...
    'fileSha256',hashes);
end

