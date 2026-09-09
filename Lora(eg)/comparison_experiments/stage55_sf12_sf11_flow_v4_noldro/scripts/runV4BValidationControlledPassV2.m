function result=runV4BValidationControlledPassV2(passIndex)
root=v4SetupPaths();c=sf12NoLdroSf11FlowConfig();list=v4BCalibrationCandidates();p=list(2);folder=fullfile(root,'results','validation','track_b','controlled_awgn','B-param-v02','passes');result=v4RunBControlledValidationPass(root,c,p,passIndex,[1500000000 1600000000 1700000000],folder,'Stage55-B-project-path-calibrated-v8');fprintf('B validation v2 pass %d complete\n',passIndex);
end
