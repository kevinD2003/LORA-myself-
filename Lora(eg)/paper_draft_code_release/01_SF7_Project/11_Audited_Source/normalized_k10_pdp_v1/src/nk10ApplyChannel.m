function output=nk10ApplyChannel(input,taps,delays)
%NK10APPLYCHANNEL Causal serial TDL across physical chirp boundaries.
assert(ismatrix(input)&&isrow(taps)&&numel(taps)==numel(delays), ...
    'Nk10:ConvolutionShape','One tap row is required.');
assert(all(delays>=0)&&all(delays==fix(delays))&& ...
    numel(unique(delays))==numel(delays),'Nk10:Delay','Delays must be unique nonnegative integers.');
serial=reshape(input.',[],1);out=complex(zeros(size(serial)));
for k=1:numel(delays)
    delay=delays(k);
    if delay<numel(serial)
        out(delay+1:end)=out(delay+1:end)+taps(k)*serial(1:end-delay);
    end
end
output=reshape(out,size(input,2),size(input,1)).';
end

