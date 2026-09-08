function [candidates,metadata]=v4Stage3SCandidateTable(root,version)
path=fullfile(root,'config',sprintf('stage3s_candidate_table_v%02d.json',version));
source=jsondecode(fileread(path));names=fieldnames(source.fullFactorial);
values=cellfun(@(n)source.fullFactorial.(n)(:).',names,'UniformOutput',false);
grid=cell(size(values));[grid{:}]=ndgrid(values{:});count=numel(grid{1});
candidates=repmat(source.fixed,count,1);
for i=1:count
    for k=1:numel(names),candidates(i).(names{k})=grid{k}(i);end
    candidates(i).innovationLimitBins=candidates(i).lockedInnovationLimitBins;
    candidates(i).branchResidualLimitBins=candidates(i).lockedHistoryResidualLimitBins;
    candidates(i).candidateIndex=i;candidates(i).parameterVersion=source.parameterVersion;
end
metadata=struct('path',path,'hash',v4Sha256(path),'candidateCount',count, ...
    'packetsPerCandidateCase',source.calibrationPacketsPerCandidateCase, ...
    'parameterVersion',source.parameterVersion);
end
