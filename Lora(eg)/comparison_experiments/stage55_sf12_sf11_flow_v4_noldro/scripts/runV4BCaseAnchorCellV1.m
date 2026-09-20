function result=runV4BCaseAnchorCellV1(caseIndex,snrIndex)
root=v4SetupPaths();c=sf12NoLdroSf11FlowConfig();list=v4BCalibrationCandidates();
result=v4RunBCaseAnchorCellV1(root,c,list(1),list(2),caseIndex,snrIndex);
fprintf('B Case-anchor Case %d SNR %g complete\n',caseIndex,result.snrDb);
end
