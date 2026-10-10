function result = dreProjectPaperExact10Decode(observation,projectConfig,mode,rawBins)
%DREPROJECTPAPEREXACT10DECODE Paper Eq. (18)-(22), ten-point centroid, no pilots.
%   The V4 frame's midambles are present in the common IQ timeline but this
%   paper-native receiver does not use them as regression observations.

layout = observation.layout;
selectedRows = [layout.bootstrapRows;layout.dataRows];
if nargin < 4
    estimatorConfig = struct('samplesPerSymbol', ...
        projectConfig.v4.samplesPerSymbol,'zeroPaddingFactor',4);
    centroid = dreEstimatePaperCentroids10( ...
        observation.rxPhysical(selectedRows,:),estimatorConfig);
    rawBins = centroid.rawBins;
end
result = dreProjectLinearRegressionDecode( ...
    observation,projectConfig,mode,rawBins);
result.methodName = ['Dietl ' char(lower(string(mode))) ...
    ' LR, ten-point centroid'];
result.methodId = ['dietl-' char(lower(string(mode))) '-lr-centroid10-v3'];
result.centroidSampleCount = 10;
result.knownMidamblesUsed = 0;
end
