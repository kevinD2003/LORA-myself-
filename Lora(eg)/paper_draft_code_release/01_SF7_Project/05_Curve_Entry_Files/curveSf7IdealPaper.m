function output = curveSf7IdealPaper(input)
%CURVESF7IDEALPAPER Describe or run the SF7 Paper-frame ideal curve.
spec = paperDraftCurveSpecSf7("sf7_ideal_paper",mfilename, ...
    "prefecNativeHardDetect","paper_129","ideal");
if nargin==0, output=spec; return; end
layout=input.pair.pilot.observation.layout;
samples=input.pair.pilotIdeal.rxPhysical(layout.dataRows,:);
output=prefecNativeHardDetect(samples,input.config.parent);
end

