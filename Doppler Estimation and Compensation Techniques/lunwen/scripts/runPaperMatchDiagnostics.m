%RUNPAPERMATCHDIAGNOSTICS Compare documented, non-production model choices.

projectRoot = fileparts(fileparts(mfilename('fullpath')));
outputFolder = fullfile(projectRoot, 'results', 'diagnostics');
if ~isfolder(outputFolder)
    mkdir(outputFolder);
end
addpath(fullfile(projectRoot, 'config'));
addpath(fullfile(projectRoot, 'src'));

limits = struct('batchPackets', 32, 'minimumPackets', 1000, ...
    'maximumPackets', 1000, 'minimumSymbolErrors', 0);
cfg = paperSf12Config();
decisionModes = ["peak_quantize", "valid_bins_only"];
strategies = ["no_doppler", "point", "midamble_point"];
rows = table();
for decisionMode = decisionModes
    cfg.radio.ldroDecisionMode = decisionMode;
    for caseName = ["case1", "case2"]
        for strategy = strategies
            result = simulateSerPoint( ...
                cfg, caseName, strategy, -21, limits);
            row = struct2table(result, 'AsArray', true);
            row.ldroDecisionMode = decisionMode;
            rows = [rows; row]; %#ok<AGROW>
        end
    end
end
rows = movevars(rows, 'ldroDecisionMode', 'Before', 'caseName');
writetable(rows, fullfile(outputFolder, ...
    'ldro_decision_endpoint.csv'));

sampleRows = table();
for spreadingFactor = [7, 12]
    if spreadingFactor == 7
        cfg = publishedSampleRicianSf7Config();
        snrDb = -6;
    else
        cfg = publishedSampleRicianSf12Config();
        snrDb = -21;
    end
    result = simulateSerPoint( ...
        cfg, "case1", "no_doppler", snrDb, limits);
    row = struct2table(result, 'AsArray', true);
    row.spreadingFactor = spreadingFactor;
    sampleRows = [sampleRows; row]; %#ok<AGROW>
end
sampleRows = movevars(sampleRows, 'spreadingFactor', ...
    'Before', 'caseName');
writetable(sampleRows, fullfile(outputFolder, ...
    'sample_rician_endpoint.csv'));
fprintf('Paper-match diagnostics written to %s\n', outputFolder);
