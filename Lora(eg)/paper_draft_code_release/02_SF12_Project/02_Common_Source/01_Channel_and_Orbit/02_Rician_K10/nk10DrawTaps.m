function [taps,delays,profile]=nk10DrawTaps(seed,count)
%NK10DRAWTAPS Packet-constant normalized K10 taps from the registered PDP.
% The LOS convention follows the public elevation-paper channel.py: equal
% deterministic real/imaginary means (phase pi/4). Diffuse power is proper
% complex Gaussian and totals 1/(K+1). No realized packet is normalized.
arguments
    seed (1,1) double {mustBeInteger,mustBeNonnegative}
    count (1,1) double {mustBeInteger,mustBePositive}=1
end
profile=nk10Profile();stream=RandStream('mt19937ar','Seed',seed);
p=profile.diffuseRelativePowers;
diffuse=sqrt(p/(2*(profile.kLinear+1))).*(randn(stream,count,numel(p))+ ...
    1i*randn(stream,count,numel(p)));
los=sqrt(profile.kLinear/(profile.kLinear+1))*exp(1i*profile.losPhaseRad);
taps=diffuse;taps(:,1)=taps(:,1)+los;delays=profile.delaysSamples;
end

