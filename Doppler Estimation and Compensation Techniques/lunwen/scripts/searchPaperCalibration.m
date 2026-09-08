%SEARCHPAPERCALIBRATION Coarse labeled fit to final-paper endpoint bands.

projectRoot = fileparts(fileparts(mfilename('fullpath')));
outputFolder = fullfile(projectRoot, 'results', 'calibrated', 'search');
if ~isfolder(outputFolder)
    mkdir(outputFolder);
end
addpath(fullfile(projectRoot, 'config'));
addpath(fullfile(projectRoot, 'src'));

kCandidatesDb = [11, 12, 13];
paddingCandidates = [1, 4, 16];
limits = struct('batchPackets', 32, 'minimumPackets', 256, ...
    'maximumPackets', 256, 'minimumSymbolErrors', 0);
reference = readtable(fullfile(projectRoot, 'reference', ...
    'paperEndpointAcceptance.csv'), 'TextType', 'string');

searchRows = table();
summaryRows = table();
for kDb = kCandidatesDb
    for paddingFactor = paddingCandidates
        squaredLogError = 0;
        matchCount = 0;
        comparisonCount = 0;
        for spreadingFactor = [7, 12]
            if spreadingFactor == 7
                cfg = paperSf7Config();
            else
                cfg = paperSf12Config();
            end
            cfg.channel.ricianKDb = kDb;
            cfg.receiver.estimatorFftPaddingFactor = paddingFactor;
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
                comparisonCount = comparisonCount + 1;
                newRow = table(kDb, paddingFactor, spreadingFactor, ...
                    paperRow.caseName, paperRow.strategy, paperRow.snrDb, ...
                    result.ser, result.symbolErrors, result.totalSymbols, ...
                    paperRow.serLow, paperRow.serHigh, targetSer, ...
                    logError, isMatch, true, ...
                    'VariableNames', {'ricianKDb', 'fftPaddingFactor', ...
                    'spreadingFactor', 'caseName', 'strategy', 'snrDb', ...
                    'ser', 'symbolErrors', 'totalSymbols', 'paperLow', ...
                    'paperHigh', 'targetSer', 'log10Ratio', ...
                    'withinPaperBand', 'fittedOrTuned'});
                searchRows = [searchRows; newRow]; %#ok<AGROW>
            end
        end
        rmsLogError = sqrt(squaredLogError/comparisonCount);
        summaryRow = table(kDb, paddingFactor, rmsLogError, ...
            matchCount, comparisonCount, true, ...
            'VariableNames', {'ricianKDb', 'fftPaddingFactor', ...
            'rmsLog10Error', 'matchCount', 'comparisonCount', ...
            'fittedOrTuned'});
        summaryRows = [summaryRows; summaryRow]; %#ok<AGROW>
        writetable(searchRows, fullfile(outputFolder, ...
            'calibration_search_points.csv'));
        writetable(summaryRows, fullfile(outputFolder, ...
            'calibration_search_summary.csv'));
        fprintf('K=%g dB padding=%g RMSlog=%g matches=%d/%d\n', ...
            kDb, paddingFactor, rmsLogError, matchCount, comparisonCount);
    end
end

summaryRows = sortrows(summaryRows, ...
    {'matchCount', 'rmsLog10Error'}, {'descend', 'ascend'});
writetable(summaryRows, fullfile(outputFolder, ...
    'calibration_search_summary.csv'));
