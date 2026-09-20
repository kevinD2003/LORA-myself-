function runV4HuangV6TestGrid()
%RUNV4HUANGV6TESTGRID Two-case, ten-SNR, 1000-packet unified PREC grid.
caseList=[ones(1,10),2*ones(1,10)];snrList=[1:10,1:10];
pool=gcp('nocreate');if isempty(pool),pool=parpool('local',3);end
parfor index=1:numel(caseList)
    v4RunHuangV6TestCell(caseList(index),snrList(index));
end
delete(pool);
end
