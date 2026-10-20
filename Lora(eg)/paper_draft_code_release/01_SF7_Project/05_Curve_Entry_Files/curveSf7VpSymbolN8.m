function output = curveSf7VpSymbolN8(input)
%CURVESF7VPSYMBOLN8 Describe or run the SF7 Symbol-VP Rolling-N8 curve.
spec = paperDraftCurveSpecSf7("sf7_vp_symbol_n8",mfilename, ...
    "senloraSymmetricV8SymbolVpDecode","native_120","vp");
if nargin==0, output=spec; return; end
assert(isstruct(input)&&isfield(input,'pair')&&isfield(input,'config'), ...
    'PaperDraft:CurveInput','Input needs pair and config fields.');
c=input.config.parent;observation=input.pair.native.observation;
p=v4LoadMethodAlignedR3ParametersV1();
common=v4CommonBootstrap(observation.rxPhysical(1:c.bootstrapPilotCount,:),c, ...
    SearchStepBins=p.searchStepBins);
output=senloraSymmetricV8SymbolVpDecode(observation,common,input.config, ...
    input.config.receiverPlan,SymbolVpHistoryLength=8);
end

