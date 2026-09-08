function states = v3InitializeReceiverStates(rxPilots,config,options)
%V3INITIALIZERECEIVERSTATES Replicate one common bootstrap to three methods.

arguments
    rxPilots (:,:) double
    config (1,1) struct
    options.SearchStepBins (1,1) double {mustBePositive} = 0.05
end

common = v3CommonBootstrap(rxPilots,config, ...
    SearchStepBins=options.SearchStepBins);
states = repmat(struct('methodName','','bootstrap',struct()),3,1);
for method = 1:3
    states(method).methodName = config.methodNames{method};
    states(method).bootstrap = common;
end
end

