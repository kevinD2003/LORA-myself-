function output = curveSf12HuangPrec(input)
%CURVESF12HUANGPREC Describe or run the SF12 Huang/PREC curve.
spec = paperDraftCurveSpecSf12("sf12_huang_prec",mfilename, ...
    "v4HuangPrecUnifiedDecodeV9","native_120","comparison");
if nargin==0, output=spec; return; end
assert(isstruct(input)&&isfield(input,'pair')&&isfield(input,'config'), ...
    'PaperDraft:CurveInput','Input needs pair and config fields.');
c=input.config.parent;observation=input.pair.native.observation;
p=v4LoadMethodAlignedR3ParametersV1();
common=v4CommonBootstrap(observation.rxPhysical(1:c.bootstrapPilotCount,:),c, ...
    SearchStepBins=p.searchStepBins);
observation.noiseVariance=common.noisePower;
output=v4HuangPrecUnifiedDecodeV9(observation,c);
end

