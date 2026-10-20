function profiles = mpK10Profiles()
%MPK10PROFILES Registered, global delay/PDP sensitivity assumptions.
% These 8-us-grid delays are new user-authorized experiments, not values
% asserted to have been specified by either cited paper.
delays = {[1],[1 2],[1 2 3 4],[2 4 6 8]};
profiles = repmat(struct('id','','delayedSamples',[],'powers',[], ...
    'losPhaseRad',0,'provenance','user-authorized-channel-sensitivity'),8,1);
index = 0;
for k=1:numel(delays)
    for exponential=[false true]
        index=index+1;d=delays{k};
        if exponential
            p=exp(-(0:numel(d)-1));label='exponential';
        else
            p=ones(size(d));label='equal';
        end
        profiles(index).id=sprintf('d%s_%s',strjoin(string(d),'-'),label);
        profiles(index).delayedSamples=d;
        profiles(index).powers=p/sum(p);
    end
end
end
