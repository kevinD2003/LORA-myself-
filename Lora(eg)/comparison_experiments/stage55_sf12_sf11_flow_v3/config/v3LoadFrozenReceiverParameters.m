function [parameters,manifest] = v3LoadFrozenReceiverParameters(config)
%V3LOADFROZENRECEIVERPARAMETERS Load only a validated frozen Stage-5 manifest.

path = fullfile(config.projectRoot,'config','receiverParameterManifest.json');
manifest = jsondecode(fileread(path));
if ~strcmp(manifest.status,'frozen') || isempty(manifest.calibratedParameters)
    error('V3:ParametersNotFrozen','Stage 5 receiver parameters are not frozen.');
end
identity = manifest.identity;
if identity.physicalSf ~= config.physicalSf || ...
        identity.effectiveDataSf ~= config.effectiveDataSf || ...
        identity.dataBinSpacing ~= config.dataBinSpacing || ...
        identity.payloadSymbols ~= config.payloadSymbolCount
    error('V3:ParameterIdentity','Receiver manifest identity does not match V3 config.');
end
parameters = manifest.calibratedParameters;
v3ValidateReceiverParameters(parameters);
expected = v3AlgorithmSignature(config.projectRoot,parameters);
if ~strcmp(expected,manifest.algorithmSignature)
    error('V3:AlgorithmSignature','Frozen receiver algorithm signature mismatch.');
end
end

