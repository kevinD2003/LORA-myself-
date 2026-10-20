function output=mpK10ApplyChannel(input,taps,delays)
%MPK10APPLYCHANNEL Causal serial convolution across physical chirp boundaries.
% Zero before the first sample; the tail after the finite packet is dropped.
% No cyclic prefix, per-symbol wrapping, or cyclic convolution is introduced.
assert(ismatrix(input)&&isrow(taps)&&numel(taps)==numel(delays), ...
    'MpK10:ConvolutionShape','One tap row and one row-per-chirp waveform required.');
assert(all(delays>=0)&&all(delays==fix(delays)), ...
    'MpK10:ConvolutionDelay','Integer causal delays required.');
serial=reshape(input.',[],1);out=complex(zeros(size(serial)));
for j=1:numel(delays)
    d=delays(j);
    if d<numel(serial),out(d+1:end)=out(d+1:end)+taps(j)*serial(1:end-d);end
end
output=reshape(out,size(input,2),size(input,1)).';
end
