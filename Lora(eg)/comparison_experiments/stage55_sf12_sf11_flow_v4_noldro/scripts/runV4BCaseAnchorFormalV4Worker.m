function runV4BCaseAnchorFormalV4Worker(workerIndex,workerCount)
arguments
 workerIndex (1,1) double {mustBeInteger,mustBePositive}
 workerCount (1,1) double {mustBeInteger,mustBePositive}
end
if workerIndex > workerCount,error('V4:BCaseAnchorWorker','Invalid worker.');end
for cellIndex = workerIndex:workerCount:32
 caseIndex = floor((cellIndex-1)/16)+1;
 snrIndex = mod(cellIndex-1,16)+1;
 runV4BCaseAnchorCellV4(caseIndex,snrIndex);
end
end
