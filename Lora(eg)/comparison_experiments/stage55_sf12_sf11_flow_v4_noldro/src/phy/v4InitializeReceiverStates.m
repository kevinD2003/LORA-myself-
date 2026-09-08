function states = v4InitializeReceiverStates(rxPilots,config,options)
%V4INITIALIZERECEIVERSTATES Replicate one common bootstrap to three methods.

arguments
    rxPilots (:,:) double
    config (1,1) struct
    options.SearchStepBins (1,1) double {mustBePositive} = 0.05
end

common = v4CommonBootstrap(rxPilots,config, ...
    SearchStepBins=options.SearchStepBins);
states = repmat(struct('methodName','','bootstrap',struct()),3,1);
for method = 1:3
    states(method).methodName = config.methodNames{method};
    states(method).bootstrap = common;
end
end

