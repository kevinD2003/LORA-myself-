function result=v4RunTrackAR14PairedPacket(c,caseTime,snrDb,id,rootSeed,p)
q=v4GenerateTrackAPacket(c,caseTime,snrDb,id,rootSeed);t=tic;no=v4PaperNoDopplerBaseline(q,c);runtime(1)=toc(t);t=tic;point=v4PaperPointBaseline(q,c);runtime(2)=toc(t);t=tic;paper=v4PaperNativeMidambleDecode(q,c,false);runtime(3)=toc(t);t=tic;stage=v4TrackAStage55DualHypothesisDecode(q,c,p);runtime(4)=toc(t);rx={no,point,paper,stage};metrics=cellfun(@(x)v4EvaluateTrackAPacket(x,q.truth,c),rx,'UniformOutput',false);result=struct('receivers',{rx},'metrics',{metrics},'runtimeSec',runtime,'truth',q.truth);
end
