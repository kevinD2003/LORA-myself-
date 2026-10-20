function output = curveSf12IdealPaper(input)
%CURVESF12IDEALPAPER Describe or run the SF12 Paper-frame ideal curve.
spec = paperDraftCurveSpecSf12("sf12_ideal_paper",mfilename, ...
    "prefecNativeHardDetect","paper_157","ideal");
if nargin==0, output=spec; return; end
layout=input.pair.pilot.observation.layout;
samples=input.pair.pilotIdeal.rxPhysical(layout.dataRows,:);
output=prefecNativeHardDetect(samples,input.config.parent);
end

