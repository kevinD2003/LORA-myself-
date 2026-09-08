function [candidates,metadata] = v4Stage3RCandidateTable(root,version)
%V4STAGE3RCANDIDATETABLE Expand a frozen 32-row full-factorial table.
path=fullfile(root,'config',sprintf('stage3r_candidate_table_v%02d.json',version));
source=jsondecode(fileread(path));
names=fieldnames(source.fullFactorial);
values=cellfun(@(n)source.fullFactorial.(n)(:).',names,'UniformOutput',false);
grid=cell(size(values)); [grid{:}]=ndgrid(values{:});
count=numel(grid{1}); candidates=repmat(source.fixed,count,1);
for index=1:count
    for field=1:numel(names),candidates(index).(names{field})=grid{field}(index);end
    candidates(index).candidateIndex=index;
    candidates(index).parameterVersion=source.parameterVersion;
end
metadata=struct('path',path,'hash',v4Sha256(path),'candidateCount',count, ...
    'calibrationPacketsPerCandidateCase',source.calibrationPacketsPerCandidateCase, ...
    'parameterVersion',source.parameterVersion);
end
