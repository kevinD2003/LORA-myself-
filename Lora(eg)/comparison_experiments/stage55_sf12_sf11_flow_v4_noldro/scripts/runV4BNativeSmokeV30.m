function result=runV4BNativeSmokeV30(channelModel)
root=v4SetupPaths();c=sf12NoLdroSf11FlowConfig();list=v4BCalibrationCandidates();folder=fullfile(root,'results','smoke','track_b',['native_' lower(channelModel)]);
existed=isfile(fullfile(folder,'pass_01.mat'))&&isfile(fullfile(folder,'pass_01.json'));
opts=struct('seedRoot',540000000,'snrDb',-24,'channelModel',channelModel, ...
 'keyPhase',['smoke-v30-native-' lower(channelModel)],'domain',['b_smoke_native_' lower(channelModel)]);
result=v4RunBNativeValidationPassV28(root,c,list(1),list(2),1,folder,'v30',opts);
if existed
    result.resumedWithoutRecount=true;
    fprintf('native %s smoke checkpoint verified without recount\n',channelModel);
    return
end
mem=memory;result.smokeOnly=true;result.channel=channelModel;result.mode='native-overhead';result.snrDb=-24;
result.allFinite=all(isfinite(result.metrics),'all');result.resumedWithoutRecount=existed;result.matlabMemoryBytes=mem.MemUsedMATLAB;
save(fullfile(folder,'pass_01.mat'),'result','-v7.3');
f=fopen(fullfile(folder,'pass_01.json'),'w','n','UTF-8');cl=onCleanup(@()fclose(f));fprintf(f,'%s\n',jsonencode(result,'PrettyPrint',true));clear cl
fprintf('native %s smoke complete\n',channelModel);
end
