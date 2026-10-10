function result = dreProjectLinearRegressionDecode(observation,projectConfig,mode,rawBins)
%DREPROJECTLINEARREGRESSIONDECODE Paper LR receiver on an unchanged V4 frame.

c = projectConfig.v4;
layout = observation.layout;
selectedRows = [layout.bootstrapRows;layout.dataRows];
if nargin < 4
    estimatorConfig = struct('samplesPerSymbol',c.samplesPerSymbol, ...
        'zeroPaddingFactor',projectConfig.zeroPaddingFactor, ...
        'centroidSampleCount',projectConfig.centroidSampleCount);
    centroid = dreEstimateCentroids(observation.rxPhysical(selectedRows,:), ...
        estimatorConfig);
    rawBins = centroid.rawBins;
else
    rawBins = double(rawBins(:));
    if numel(rawBins) ~= numel(selectedRows)
        error('DRE:ProjectRawBinShape','Expected one centroid per selected row.');
    end
end
decoderConfig = struct('samplesPerSymbol',c.samplesPerSymbol, ...
    'preambleSymbolCount',c.bootstrapPilotCount);
decoded = dreDecodeLinearRegression(rawBins, ...
    zeros(c.bootstrapPilotCount,1),decoderConfig,mode,selectedRows-1);
hardBits = dreDecodeProjectHardBits(decoded.detectedSymbols,c);
result = struct('methodName',['Dietl ' upperFirst(mode) ' LR'], ...
    'methodId',['dietl-' lower(mode) '-lr-v1'], ...
    'detectedPhysicalBins',decoded.detectedSymbols, ...
    'hardDecodedDataBits',hardBits,'linearRegression',decoded, ...
    'usesPayloadTruth',false,'usesOrbitTruth',false, ...
    'usesPayloadFeedback',strcmpi(mode,'adaptive'), ...
    'fftCount',numel(selectedRows));
end

function output = upperFirst(input)
output = char(lower(string(input)));
output(1) = upper(output(1));
end
