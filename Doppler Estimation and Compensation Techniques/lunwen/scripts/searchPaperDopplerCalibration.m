%SEARCHPAPERDOPPLERCALIBRATION Refine the labeled endpoint calibration.

projectRoot = fileparts(fileparts(mfilename('fullpath')));
outputFolder = fullfile(projectRoot, 'results', 'calibrated', 'search');
if ~isfolder(outputFolder)
    mkdir(outputFolder);
end
addpath(fullfile(projectRoot, 'config'));
addpath(fullfile(projectRoot, 'src'));

rateScaleCandidates = [0.5, 0.6, 0.7, 0.8, 0.9];
limits = struct('batchPackets', 32, 'minimumPackets', 256, ...
    'maximumPackets', 256, 'minimumSymbolErrors', 0);
reference = readtable(fullfile(projectRoot, 'reference', ...
    'paperEndpointAcceptance.csv'), 'TextType', 'string');
searchRows = table();
summaryRows = table();

for rateScale = rateScaleCandidates
    squaredLogError = 0;
    matchCount = 0;
    for spreadingFactor = [7, 12]
        if spreadingFactor == 7
            cfg = paperSf7Config();
        else
            cfg = paperSf12Config();
        end
        cfg.channel.ricianKDb = 12;
        cfg.receiver.estimatorFftPaddingFactor = 4;
        cfg.orbit.frameDopplerTimeScale = rateScale;
        cfg.provenance.profile = "paper_endpoint_calibration_search";
        cfg.provenance.fittedOrTuned = true;
        selectedReference = reference( ...
            reference.spreadingFactor == spreadingFactor, :);
        for rowIndex = 1:height(selectedReference)
            paperRow = selectedReference(rowIndex, :);
            result = simulateSerPoint(cfg, paperRow.caseName, ...
                paperRow.strategy, paperRow.snrDb, limits);
            stableSer = (result.symbolErrors + 0.5)/ ...
                (result.totalSymbols + 1);
            targetSer = sqrt(paperRow.serLow*paperRow.serHigh);
            logError = log10(stableSer/targetSer);
            isMatch = result.ser >= paperRow.serLow && ...
                result.ser <= paperRow.serHigh;
            squaredLogError = squaredLogError + logError^2;
            matchCount = matchCount + double(isMatch);
            newRow = table(rateScale, spreadingFactor, ...
                paperRow.caseName, paperRow.strategy, paperRow.snrDb, ...
                result.ser, result.symbolErrors, result.totalSymbols, ...
                paperRow.serLow, paperRow.serHigh, targetSer, ...
                logError, isMatch, true, ...
                'VariableNames', {'dopplerTimeScale', ...
                'spreadingFactor', 'caseName', 'strategy', 'snrDb', ...
                'ser', 'symbolErrors', 'totalSymbols', 'paperLow', ...
                'paperHigh', 'targetSer', 'log10Ratio', ...
                'withinPaperBand', 'fittedOrTuned'});
            searchRows = [searchRows; newRow]; %#ok<AGROW>
        end
    end
    comparisonCount = 12;
    rmsLogError = sqrt(squaredLogError/comparisonCount);
    summaryRows = [summaryRows; table(rateScale, rmsLogError, ...
        matchCount, comparisonCount, true, ...
        'VariableNames', {'dopplerTimeScale', 'rmsLog10Error', ...
        'matchCount', 'comparisonCount', 'fittedOrTuned'})]; %#ok<AGROW>
    writetable(searchRows, fullfile(outputFolder, ...
        'doppler_calibration_search_points.csv'));
    writetable(summaryRows, fullfile(outputFolder, ...
        'doppler_calibration_search_summary.csv'));
    fprintf('rateScale=%g RMSlog=%g matches=%d/%d\n', ...
        rateScale, rmsLogError, matchCount, comparisonCount);
end

summaryRows = sortrows(summaryRows, ...
    {'matchCount', 'rmsLog10Error'}, {'descend', 'ascend'});
writetable(summaryRows, fullfile(outputFolder, ...
    'doppler_calibration_search_summary.csv'));
