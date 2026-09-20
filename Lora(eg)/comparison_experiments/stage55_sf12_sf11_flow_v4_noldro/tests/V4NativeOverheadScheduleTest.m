classdef V4NativeOverheadScheduleTest < matlab.unittest.TestCase
 methods (Test)
  function naturalDurationsAndLayouts(testCase)
   c=sf12NoLdroSf11FlowConfig();short=v4NativeOverheadSchedule(c,'short');paper=v4NativeOverheadSchedule(c,'paper');
   testCase.verifyEqual(short.frameSymbolCount,120);testCase.verifyEqual(paper.frameSymbolCount,157);
   testCase.verifyEqual(short.frameDurationSec,120*c.symbolDurationSec,'AbsTol',1e-12);
   testCase.verifyEqual(paper.frameDurationSec,157*c.symbolDurationSec,'AbsTol',1e-12);
   testCase.verifyGreaterThan(short.frameCount,paper.frameCount);
   a=v4BuildNativeFrameLayout(c,false);b=v4BuildNativeFrameLayout(c,true);
   testCase.verifyEqual(a.physicalSymbolCount,120);testCase.verifyEmpty(a.midambleRows);
   testCase.verifyEqual(b.physicalSymbolCount,157);testCase.verifyNumElements(b.midambleRows,37);
  end
  function backToBackAndVisibilityDenominators(testCase)
   c=sf12NoLdroSf11FlowConfig();for type={'short','paper'},s=v4NativeOverheadSchedule(c,type{1});
    testCase.verifyEqual(diff(s.frameStartTimeSec),repmat(s.frameDurationSec,s.frameCount-1,1),'AbsTol',1e-12);
    testCase.verifyEqual(s.interFrameGapSec,0);testCase.verifyFalse(any(s.metricEligible&s.fullyBlind));
   end
  end
  function nativePhaseBridgesAndNoiselessRoundTrip(testCase)
   c=sf12NoLdroSf11FlowConfig();c.carrierFrequencyHz=0;s=v4NativeOverheadSchedule(c,'short');
   key=struct('planVersion','V4-noLDRO-plan-R3-project-aligned','phase','native-test','track','B','channel','AWGN', ...
    'comparisonMode','native-overhead','snrDb',Inf,'replicateId',1,'packetId',1,'eventType','native-short-frame','eventIndex',1,'sampleIndex',0);
   l=v4EventRandomLedger(410000000,key);f=v4GenerateNativeFrame(c,s.frameStartTimeSec(1),Inf,l,0,'AWGN',false);
   b=v4CommonBootstrap(f.observation.rxPhysical(1:8,:),c,SearchStepBins=.05);r=v4HuangStaticDecode(f.observation,b,c);m=v4EvaluateFrame(r,f.truth,c);
   testCase.verifyEqual([m.symbolErrors m.hardBitErrors m.softBitErrors],[0 0 0]);
   key.packetId=2;key.eventIndex=2;l2=v4EventRandomLedger(410000000,key);g=v4GenerateNativeFrame(c,f.nextFrameStartTimeSec,Inf,l2,f.nextFrameStartPhaseRad,'AWGN',false);
   testCase.verifyEqual(angle(exp(1i*(g.truth.firstSamplePhaseRad-f.nextFrameStartPhaseRad))),0,'AbsTol',1e-12);
  end
 end
end
