function parameters=v4LoadMethodAlignedParametersV1()
%V4LOADMETHODALIGNEDPARAMETERSV1 Load the quality-selected frozen candidate.
path=fullfile(fileparts(mfilename('fullpath')), ...
    'method_aligned_selected_parameters_v1.json');
j=jsondecode(fileread(path));
parameters=rmfield(j,{'planVersion','parameterVersion', ...
    'selectedByCalibrationSha256','residualSearchStartBins', ...
    'residualSearchStepBins','residualSearchEndBins','baseCandidateIndex'});
parameters.residualSearchBins=(j.residualSearchStartBins: ...
    j.residualSearchStepBins:j.residualSearchEndBins).';
parameters.parameterVersion=j.parameterVersion;
parameters.planVersion=j.planVersion;
parameters.sourcePath=path;
parameters.sourceHash=v4Sha256(path);
v4ValidateReceiverParameters(parameters);
end

