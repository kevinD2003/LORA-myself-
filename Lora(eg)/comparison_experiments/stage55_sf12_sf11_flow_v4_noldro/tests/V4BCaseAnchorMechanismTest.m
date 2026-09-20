classdef V4BCaseAnchorMechanismTest < matlab.unittest.TestCase
 methods (Test)
  function casesHaveRequiredCfoAndRateRegimes(testCase)
   c=sf12NoLdroSf11FlowConfig();a=v4TrackAOrbit([-366.01;-366;-365.99],c);b=v4TrackAOrbit([-.01;0;.01],c);
   rateA=(a.dopplerHz(3)-a.dopplerHz(1))/.02/c.fftBinSpacingHz;rateB=(b.dopplerHz(3)-b.dopplerHz(1))/.02/c.fftBinSpacingHz;
   testCase.verifyGreaterThan(abs(a.dopplerHz(2)/c.fftBinSpacingHz),600);testCase.verifyLessThan(abs(rateA),.01);
   testCase.verifyLessThan(abs(b.dopplerHz(2)/c.fftBinSpacingHz),.01);testCase.verifyGreaterThan(abs(rateB),9);
  end
  function huangDecodesNoiselessHighCfoLowRateCase(testCase)
   c=sf12NoLdroSf11FlowConfig();key=struct('planVersion','B-case-anchor-AWGN-v1','phase','mechanism', ...
    'track','B-case-anchor','channel','AWGN','comparisonMode','case-anchor-controlled', ...
    'snrDb',Inf,'replicateId',1,'packetId',1,'eventType','paired-frame','eventIndex',1,'sampleIndex',0);
   ledger=v4EventRandomLedger(579000000,key);frame=v4GenerateBCaseAnchorFrame(c,-366,Inf,ledger);
   bootstrap=v4CommonBootstrap(frame.observation.rxPhysical(1:8,:),c,SearchStepBins=.05);
   huang=v4HuangStaticDecode(frame.observation,bootstrap,c);m=v4EvaluateFrame(huang,frame.truth,c);
   testCase.verifyEqual([m.symbolErrors m.hardBitErrors m.softBitErrors],[0 0 0]);
   testCase.verifyGreaterThan(abs(bootstrap.epsilonHatBins),600);
  end
 end
end
