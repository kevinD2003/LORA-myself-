function result=v4RunTrackAStage3SPairedPacket(config,caseTime,snrDb,packetId,rootSeed,parameters)
packet=v4GenerateTrackAPacket(config,caseTime,snrDb,packetId,rootSeed);
t=tic;no=v4PaperNoDopplerBaseline(packet,config);runtime(1)=toc(t);
t=tic;point=v4PaperPointBaseline(packet,config);runtime(2)=toc(t);
t=tic;paper=v4PaperNativeMidambleDecode(packet,config,false);runtime(3)=toc(t);
t=tic;stage=v4TrackAStage55PointAnchoredDecode(packet,config,parameters);runtime(4)=toc(t);
rx={no,point,paper,stage};metrics=cellfun(@(x)v4EvaluateTrackAPacket(x,packet.truth,config),rx,'UniformOutput',false);
result=struct('packetId',packetId,'caseStartTimeSec',caseTime,'snrDb',snrDb, ...
    'receivers',{rx},'metrics',{metrics},'runtimeSec',runtime,'truth',packet.truth,'seedRoot',rootSeed);
end
