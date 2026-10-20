function output = curveSf12PaperMidamblePoint(input)
%CURVESF12PAPERMIDAMBLEPOINT Describe or run the SF12 Paper curve.
spec = paperDraftCurveSpecSf12("sf12_paper_midamble_point",mfilename, ...
    "prefecPaperNativeDecode","paper_157","comparison");
if nargin==0, output=spec; return; end
assert(isstruct(input)&&isfield(input,'pair')&&isfield(input,'config'), ...
    'PaperDraft:CurveInput','Input needs pair and config fields.');
output=prefecPaperNativeDecode(input.pair.pilot.observation,input.config.parent);
end

