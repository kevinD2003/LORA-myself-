function output = curveSf7IdealNative(input)
%CURVESF7IDEALNATIVE Describe or run the SF7 native-frame ideal curve.
spec = paperDraftCurveSpecSf7("sf7_ideal_native",mfilename, ...
    "prefecNativeHardDetect","native_120","ideal");
if nargin==0, output=spec; return; end
layout=input.pair.native.observation.layout;
samples=input.pair.nativeIdeal.rxPhysical(layout.dataRows,:);
output=prefecNativeHardDetect(samples,input.config.parent);
end

