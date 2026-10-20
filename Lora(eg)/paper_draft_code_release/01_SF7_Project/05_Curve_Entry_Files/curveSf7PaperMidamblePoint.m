function output = curveSf7PaperMidamblePoint(input)
%CURVESF7PAPERMIDAMBLEPOINT Describe or run the SF7 Paper curve.
spec = paperDraftCurveSpecSf7("sf7_paper_midamble_point",mfilename, ...
    "prefecPaperNativeDecode","paper_129","comparison");
if nargin==0, output=spec; return; end
assert(isstruct(input)&&isfield(input,'pair')&&isfield(input,'config'), ...
    'PaperDraft:CurveInput','Input needs pair and config fields.');
output=prefecPaperNativeDecode(input.pair.pilot.observation,input.config.parent);
end

