function v3WriteCheckpointAtomic(path,state,signature)
%V3WRITECHECKPOINTATOMIC Save a versioned checkpoint by atomic rename.

folder = fileparts(path);
if ~isfolder(folder), mkdir(folder); end
temporary = [tempname(folder) '.mat'];
cleanup = onCleanup(@()localDeleteIfPresent(temporary));
save(temporary,'state','signature','-v7.3');
movefile(temporary,path,'f');
clear cleanup
end

function localDeleteIfPresent(path)
if isfile(path), delete(path); end
end

