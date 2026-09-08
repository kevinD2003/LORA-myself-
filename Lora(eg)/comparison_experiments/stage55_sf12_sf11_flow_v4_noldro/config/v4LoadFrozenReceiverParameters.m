function [parameters,manifest] = v4LoadFrozenReceiverParameters(config)
%V4LOADFROZENRECEIVERPARAMETERS Load only a validated frozen Stage-5 manifest.

path = fullfile(config.projectRoot,'config','receiverParameterManifest.json');
manifest = jsondecode(fileread(path));
if ~strcmp(manifest.status,'frozen') || isempty(manifest.calibratedParameters)
    error('V4:ParametersNotFrozen','Stage 5 receiver parameters are not frozen.');
end
identity = manifest.identity;
if identity.physicalSf ~= config.physicalSf || ...
        identity.effectiveDataSf ~= config.effectiveDataSf || ...
        identity.dataBinSpacing ~= config.dataBinSpacing || ...
        identity.payloadSymbols ~= config.payloadSymbolCount
    error('V4:ParameterIdentity','Receiver manifest identity does not match V4 config.');
end
parameters = manifest.calibratedParameters;
v4ValidateReceiverParameters(parameters);
expected = v4AlgorithmSignature(config.projectRoot,parameters);
if ~strcmp(expected,manifest.algorithmSignature)
    error('V4:AlgorithmSignature','Frozen receiver algorithm signature mismatch.');
end
end

