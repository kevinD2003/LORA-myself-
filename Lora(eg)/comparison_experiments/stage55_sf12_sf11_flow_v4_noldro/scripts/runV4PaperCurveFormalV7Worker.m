function runV4PaperCurveFormalV7Worker(workerIndex,workerCount)
for snrIndex = workerIndex:workerCount:10
    runV4PaperCurveCellV7(snrIndex);
end
end
