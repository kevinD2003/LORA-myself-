function output = curveSf12AwgnTheory(snrDb)
%CURVESF12AWGNTHEORY Describe or compute the SF12 AWGN reference curve.
spec = paperDraftCurveSpecSf12("sf12_awgn_theory",mfilename, ...
    "senloraSymmetricV8AwgnTheory","single_symbol","theory");
if nargin==0, output=spec; return; end
output=senloraSymmetricV8AwgnTheory(12,snrDb(:));
end

