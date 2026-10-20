function output = curveSf7AwgnTheory(snrDb)
%CURVESF7AWGNTHEORY Describe or compute the SF7 AWGN reference curve.
spec = paperDraftCurveSpecSf7("sf7_awgn_theory",mfilename, ...
    "senloraSymmetricV8AwgnTheory","single_symbol","theory");
if nargin==0, output=spec; return; end
output=senloraSymmetricV8AwgnTheory(7,snrDb(:));
end

