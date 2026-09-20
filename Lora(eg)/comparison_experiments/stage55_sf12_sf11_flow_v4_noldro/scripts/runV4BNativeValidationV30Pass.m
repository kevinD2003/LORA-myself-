function result=runV4BNativeValidationV30Pass(passIndex)
root=v4SetupPaths();c=sf12NoLdroSf11FlowConfig();list=v4BCalibrationCandidates();folder=fullfile(root,'results','validation','track_b','native_awgn','Stage55-B-v30','passes');
result=v4RunBNativeValidationPassV28(root,c,list(1),list(2),passIndex,folder,'v30');fprintf('B native v30 pass %d complete\n',passIndex);
end
