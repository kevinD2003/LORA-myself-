function parameters=v4LoadMethodAlignedR3ParametersV1()
%V4LOADMETHODALIGNEDR3PARAMETERSV1 Load frozen V14 receiver parameters.
path=fullfile(fileparts(mfilename('fullpath')), ...
    'method_aligned_r3_selected_parameters_v1.json');
j=jsondecode(fileread(path));parameters=v4LoadMethodAlignedParametersV1();
fields={'modeLargeToCentralRatio','rateBankMaximumCount', ...
    'rateBankLeadingBlocks','rateBankPreambleLogWeight', ...
    'vpProcessingGainMinimum','leaveOneOutMinimumMarginRatio'};
for index=1:numel(fields),parameters.(fields{index})=j.(fields{index});end
parameters.parameterVersion=j.parameterVersion;
parameters.planVersion=j.planVersion;parameters.sourcePath=path;
parameters.sourceHash=v4Sha256(path);
end
