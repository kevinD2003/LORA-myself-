function result=runV4BControlledValidationV30Pass(passIndex)
root=v4SetupPaths();c=sf12NoLdroSf11FlowConfig();list=v4BCalibrationCandidates();folder=fullfile(root,'results','validation','track_b','controlled_awgn','Stage55-B-v30','passes');
result=v4RunBControlledValidationPassV24(root,c,list(1),list(2),passIndex,folder,'v30');fprintf('B controlled v30 pass %d complete\n',passIndex);
end
