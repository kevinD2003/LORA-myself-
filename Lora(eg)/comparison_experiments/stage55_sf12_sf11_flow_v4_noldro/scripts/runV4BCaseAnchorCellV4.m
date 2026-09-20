function result = runV4BCaseAnchorCellV4(caseIndex,snrIndex)
root = v4SetupPaths();c = sf12NoLdroSf11FlowConfig();
list = v4BCalibrationCandidates();
result = v4RunBCaseAnchorCellV4(root,c,list(1),list(2),caseIndex,snrIndex);
fprintf('B Case-anchor V4 Case %d SNR %g complete\n', ...
 caseIndex,result.snrDb);
end
