function result = runV4PaperCurveCellV7(snrIndex)
root = v4SetupPaths();c = sf12NoLdroSf11FlowConfig();
result = v4RunPaperCurveCellV7(root,c,snrIndex);
fprintf('Paper curve V7 SNR %g complete\n',result.snrDb);
end
