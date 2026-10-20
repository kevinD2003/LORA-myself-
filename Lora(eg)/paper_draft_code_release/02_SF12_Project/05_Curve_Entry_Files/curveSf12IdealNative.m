function output = curveSf12IdealNative(input)
%CURVESF12IDEALNATIVE Describe or run the SF12 native-frame ideal curve.
spec = paperDraftCurveSpecSf12("sf12_ideal_native",mfilename, ...
    "prefecNativeHardDetect","native_120","ideal");
if nargin==0, output=spec; return; end
layout=input.pair.native.observation.layout;
samples=input.pair.nativeIdeal.rxPhysical(layout.dataRows,:);
output=prefecNativeHardDetect(samples,input.config.parent);
end

