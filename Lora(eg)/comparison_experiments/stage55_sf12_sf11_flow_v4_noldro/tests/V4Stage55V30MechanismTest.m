classdef V4Stage55V30MechanismTest < matlab.unittest.TestCase
 methods (Test)
  function thresholdsAreObservableAndHistoryGuarded(testCase)
   root=v4SetupPaths();text=fileread(fullfile(root,'src','stage55','v4Stage55DualBootstrapDecodeV30.m'));
   testCase.verifyTrue(contains(text,'log(c.dataAlphabetSize*h)'));testCase.verifyTrue(contains(text,'options.CommonHistoryCount<=1'));
   testCase.verifyFalse(contains(text,'frame.truth'));testCase.verifyFalse(contains(text,'observation.truth'));
  end
 end
end
