function [llr,clipped] = referenceSoftLlr(power,reduced)
%REFERENCESOFTLLR Reference max-log likelihood, including reference /4 mapping.
% GPL-3.0 gr-lora_sdr 31243b0ac9cc..., fft_demod_impl.cc.
% log I0 is monotonic: max(log I0(a*sqrt(E)))=log I0(a*sqrt(max(E))).
% Taking bit-group maxima first is an exact max-log optimization, not tuning.
arguments
    power (:,:) double
    reduced (1,1) logical
end
[n,streams]=size(power);sf=log2(n);rows=sf-2*double(reduced);
if streams==0 || sf~=fix(sf) || sf<7 || sf>12 || ...
        any(~isfinite(power(:)) | power(:)<0)
    error('ReferenceSoft:Power','Expected finite nonnegative 2^SF spectra.');
end
[peak,peakIndex]=max(power,[],1);bins=(0:n-1).';
adjacent=mod(abs(bins-(peakIndex-1)),n-1)<2;
signalPower=sum(power.*adjacent,1)/n;
noisePower=sum(power.*~adjacent,1)/(n-3);
scale=zeros(1,streams);valid=noisePower>0;
scale(valid)=sqrt(signalPower(valid))./noisePower(valid);
% Reference lines 187-195 scale FFT energy by N AFTER estimating Ps/Pn.
% This affects Bessel arguments, clipping decisions and cross-symbol weights.
if any(power(:)>realmax/n),error('ReferenceSoft:Power','Scaled FFT energy would overflow.');end
clipped=(~valid & peak>0) | scale.*sqrt(n*peak)>=713;
labels=dreGrayEncode(uint32(floor(mod(bins-1,n)/(1+3*double(reduced)))));
llr=zeros(rows,streams);
for bit=1:rows
    one=logical(bitget(labels,rows-bit+1));
    p1=n*max(power(one,:),[],1);p0=n*max(power(~one,:),[],1);
    a1=scale.*sqrt(p1);a0=scale.*sqrt(p0);
    ordinary=~clipped;
    % Exponentially scaled I0 avoids overflow while computing the same log I0.
    l1=log(besseli(0,a1(ordinary),1))+a1(ordinary);
    l0=log(besseli(0,a0(ordinary),1))+a0(ordinary);
    llr(bit,ordinary)=l1-l0;
    llr(bit,clipped)=p1(clipped)-p0(clipped);
end
if any(~isfinite(llr(:))),error('ReferenceSoft:LLR','Nonfinite derived likelihood.');end
end
