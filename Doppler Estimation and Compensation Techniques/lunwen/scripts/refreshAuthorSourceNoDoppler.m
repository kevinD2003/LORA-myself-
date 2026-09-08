%REFRESHAUTHORSOURCENODOPPLER Recompute corrected complex-AWGN baselines.

projectRoot = fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(projectRoot, 'config'));
addpath(fullfile(projectRoot, 'src'));
resultsFolder = fullfile(projectRoot, 'results');
configs = {authorFigureSf7Config(), authorFigureSf12Config()};

for configIndex = 1:numel(configs)
    cfg = configs{configIndex};
    limits = monteCarloLimits(cfg, "full");
    for caseName = ["case1", "case2"]
        baseName = caseName + "_sf" + ...
            string(cfg.radio.spreadingFactor) + "_author_source";
        csvPath = fullfile(resultsFolder, baseName + ".csv");
        pngPath = fullfile(resultsFolder, baseName + ".png");
        existing = readtable(csvPath, 'TextType', 'string');
        refreshed = struct([]);
        for snrIndex = 1:numel(cfg.monteCarlo.snrDb)
            current = simulateSerPoint(cfg, caseName, ...
                "no_doppler", cfg.monteCarlo.snrDb(snrIndex), limits);
            if snrIndex == 1
                refreshed = current;
            else
                refreshed(snrIndex) = current;
            end
            fprintf('Refresh SF=%d %s no_doppler SNR=%g SER=%g\n', ...
                cfg.radio.spreadingFactor, caseName, ...
                current.snrDb, current.ser);
        end
        refreshedTable = struct2table(refreshed);
        otherStrategies = existing(existing.strategy ~= ...
            "no_doppler", :);
        updated = [refreshedTable; otherStrategies];
        writetable(updated, csvPath);
        if caseName == "case1"
            caseLabel = "Case 1";
        else
            caseLabel = "Case 2";
        end
        plotSerResults(csvPath, pngPath, caseLabel + ...
            " - SF = " + string(cfg.radio.spreadingFactor), cfg);
    end
end

combineCaseFigureFiles( ...
    fullfile(resultsFolder, 'case1_sf7_author_source.png'), ...
    fullfile(resultsFolder, 'case2_sf7_author_source.png'), ...
    fullfile(resultsFolder, 'author_source_sf7_case1_case2.png'));
combineCaseFigureFiles( ...
    fullfile(resultsFolder, 'case1_sf12_author_source.png'), ...
    fullfile(resultsFolder, 'case2_sf12_author_source.png'), ...
    fullfile(resultsFolder, 'author_source_sf12_case1_case2.png'));
fprintf('Author-source no-Doppler baselines refreshed.\n');
