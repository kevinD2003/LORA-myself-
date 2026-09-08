function result = v4RunTrackAPairedPacket(config,caseStartTimeSec,snrDb,packetId,rootSeed,parameters)
%V4RUNTRACKAPAIREDPACKET Generate once and evaluate all paired Track A methods.
packet = v4GenerateTrackAPacket(config,caseStartTimeSec,snrDb,packetId,rootSeed);
ticId = tic; noDoppler = v4PaperNoDopplerBaseline(packet,config); runtimeNo = toc(ticId);
ticId = tic; point = v4PaperPointBaseline(packet,config); runtimePoint = toc(ticId);
ticId = tic; paper = v4PaperNativeMidambleDecode(packet,config,false); runtimePaper = toc(ticId);
ticId = tic; stage55 = v4TrackAStage55Decode(packet,config,parameters); runtimeStage = toc(ticId);
receivers = {noDoppler,point,paper,stage55};
runtimes = [runtimeNo runtimePoint runtimePaper runtimeStage];
metrics = cellfun(@(x)v4EvaluateTrackAPacket(x,packet.truth,config),receivers, ...
    'UniformOutput',false);
result = struct('packetId',packetId,'caseStartTimeSec',caseStartTimeSec, ...
    'snrDb',snrDb,'receivers',{receivers},'metrics',{metrics},'runtimeSec',runtimes, ...
    'truth',packet.truth,'schedule',packet.schedule,'seedRoot',rootSeed);
end
