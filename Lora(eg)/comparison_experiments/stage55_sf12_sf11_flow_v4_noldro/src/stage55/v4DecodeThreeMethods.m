function receivers = v4DecodeThreeMethods(observation,config,parameters,options)
%V4DECODETHREEMETHODS Run the three fixed V4 branches on one observation.

arguments
    observation (1,1) struct
    config (1,1) struct
    parameters (1,1) struct
    options.Bootstrap (1,1) struct = struct()
    options.CrossFrameRateBinsPerSec (1,1) double = NaN
    options.CrossFrameHistoryCount (1,1) double {mustBeInteger,mustBeNonnegative} = 0
end

if isempty(fieldnames(options.Bootstrap))
    bootstrapRows = observation.layout.bootstrapRows;
    bootstrap = v4CommonBootstrap(observation.rxPhysical(bootstrapRows,:),config, ...
        SearchStepBins=parameters.searchStepBins);
else
    bootstrap = options.Bootstrap;
end
receivers = cell(3,1);
receivers{1} = v4HuangStaticDecode(observation,bootstrap,config);
receivers{2} = v4Stage55Decode(observation,bootstrap,config,parameters, ...
    CrossFrameRateBinsPerSec=options.CrossFrameRateBinsPerSec, ...
    CrossFrameHistoryCount=options.CrossFrameHistoryCount);
receivers{3} = v4PaperMidambleDecode(observation,bootstrap,config,parameters);
end
