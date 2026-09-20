function result=runV4BFormalPassV30(groupName,snrDb,passIndex)
root=v4SetupPaths();c=sf12NoLdroSf11FlowConfig();list=v4BCalibrationCandidates();lowP=list(1);highP=list(2);
groups=struct( ...
 'B_AWGN_CONTROLLED',struct('channel','AWGN','mode','controlled','seedRoot',551000000), ...
 'B_AWGN_NATIVE',struct('channel','AWGN','mode','native','seedRoot',552000000), ...
 'B_RICIAN_CONTROLLED',struct('channel','Rician','mode','controlled','seedRoot',553000000), ...
 'B_RICIAN_NATIVE',struct('channel','Rician','mode','native','seedRoot',554000000));
if ~isfield(groups,groupName),error('V4:FormalGroup','Unknown formal group.');end;g=groups.(groupName);
folder=fullfile(root,'results','formal','track_b',groupName,sprintf('snr_%+03d',snrDb),'passes');
opts=struct('seedRoot',g.seedRoot,'snrDb',snrDb,'channelModel',g.channel, ...
 'keyPhase',['formal-v30-' lower(groupName)],'domain',['formal-v30-' lower(groupName)],'passIndex',passIndex);
if strcmp(g.mode,'controlled')
 result=v4RunBControlledSmokePassV30(root,c,lowP,highP,g.channel,folder,opts);
else
 result=v4RunBNativeValidationPassV28(root,c,lowP,highP,passIndex,folder,'v30',opts);
end
fprintf('%s SNR %g pass %d complete\n',groupName,snrDb,passIndex);
end
