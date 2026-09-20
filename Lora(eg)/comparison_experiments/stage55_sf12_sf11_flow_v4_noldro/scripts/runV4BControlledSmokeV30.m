function result=runV4BControlledSmokeV30(channelModel)
root=v4SetupPaths();c=sf12NoLdroSf11FlowConfig();list=v4BCalibrationCandidates();folder=fullfile(root,'results','smoke','track_b',['controlled_' lower(channelModel)]);
result=v4RunBControlledSmokePassV30(root,c,list(1),list(2),channelModel,folder);fprintf('controlled %s smoke complete\n',channelModel);
end
