function [taps,delays,profile]=mpK10DiffuseTaps(profile,seed,count)
%MPK10DIFFUSETAPS One LOS plus proper-CN diffuse taps; K=10 dB total.
% Every row represents one independently faded packet. Taps remain constant
% within its packet. No realized tap/sample power is normalized.
arguments
    profile (1,1) struct
    seed (1,1) double {mustBeInteger,mustBeNonnegative}
    count (1,1) double {mustBeInteger,mustBePositive}=1
end
profile=mpK10ValidateProfile(profile);
stream=RandStream('mt19937ar','Seed',seed);
scatter=sqrt(profile.powers/22).*(randn(stream,count,numel(profile.powers))+ ...
    1i*randn(stream,count,numel(profile.powers)));
los=repmat(sqrt(10/11)*exp(1i*profile.losPhaseRad),count,1);
taps=[los scatter];delays=[0 profile.delayedSamples];
end
