function result = runV4BCaseAnchorCellV5(caseIndex,snrIndex)
root = v4SetupPaths();c = sf12NoLdroSf11FlowConfig();
list = v4BCalibrationCandidates();
result = v4RunBCaseAnchorCellV5(root,c,list(1),list(2),caseIndex,snrIndex);
fprintf('B Case-anchor V5 Case %d SNR %g complete\n',caseIndex,result.snrDb);
end
