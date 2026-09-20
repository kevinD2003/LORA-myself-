function runV4BCaseAnchorFormalV2Worker(workerIndex,workerCount)
arguments
    workerIndex (1,1) double {mustBeInteger,mustBePositive}
    workerCount (1,1) double {mustBeInteger,mustBePositive}
end
if workerIndex > workerCount
    error('V4:BCaseAnchorWorker','Worker index exceeds worker count.');
end
for cellIndex = workerIndex:workerCount:20
    caseIndex = floor((cellIndex-1)/10)+1;
    snrIndex = mod(cellIndex-1,10)+1;
    runV4BCaseAnchorCellV2(caseIndex,snrIndex);
end
end
