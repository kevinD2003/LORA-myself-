function report = build_fuxian_stage55_report(options)
%BUILD_FUXIAN_STAGE55_REPORT Build final statistics and two primary figures.

arguments
    options.ReplayMatFile (1,:) char = fullfile(fileparts( ...
        mfilename('fullpath')),'results', ...
        'stage55_sf11_midamble_three_method_replay', ...
        'fuxian_three_method_replay.mat')
    options.OutputFolderName (1,:) char = 'final'
    options.WindowDurationSec (1,1) double {mustBePositive} = 10
end

comparisonRoot = fileparts(mfilename('fullpath'));
sourceRoot = fuxianSourceRoot(comparisonRoot);
savedPath = path;
restorePath = onCleanup(@() path(savedPath));
addpath(sourceRoot,'-begin');
if ~isfile(options.ReplayMatFile)
    error('FuxianDuibi:ReportInput', ...
        'Replay MAT file not found: %s',options.ReplayMatFile);
end
source = load(options.ReplayMatFile);
required = {'records','schedule','experiment','config','options'};
for index = 1:numel(required)
    if ~isfield(source,required{index})
        error('FuxianDuibi:ReportField', ...
            'Replay source is missing %s.',required{index});
    end
end

statistics = fuxianBuildStatistics( ...
    source.records,source.schedule,source.experiment, ...
    WindowDurationSec=options.WindowDurationSec);
outputFolder = fullfile(comparisonRoot,'results', ...
    options.OutputFolderName);
if ~isfolder(outputFolder)
    mkdir(outputFolder);
end
summaryCsv = fullfile(outputFolder, ...
    'sf11_three_method_region_summary.csv');
windowCsv = fullfile(outputFolder, ...
    'sf11_three_method_window_statistics.csv');
mappingCsv = fullfile(outputFolder, ...
    'sf11_three_method_mapping.csv');
writetable(statistics.summary,summaryCsv);
writetable(statistics.windowStatistics,windowCsv);
mapping = table(string(source.experiment.methodNames), ...
    string(source.experiment.methodLabels), ...
    'VariableNames',{'sourceMethod','plotLabel'});
writetable(mapping,mappingCsv);

figureManifest = fuxianPlotTrajectoryComparison( ...
    statistics.windowStatistics,source.records, ...
    source.config,source.schedule,source.experiment,outputFolder);
manifestCsv = fullfile(outputFolder, ...
    'sf11_three_method_figure_manifest.csv');
writetable(figureManifest,manifestCsv);
matFile = fullfile(outputFolder, ...
    'sf11_stage55_three_method_report.mat');
records = source.records;
summary = statistics.summary;
windowStatistics = statistics.windowStatistics;
experiment = source.experiment;
config = source.config;
schedule = source.schedule;
replayOptions = source.options;
save(matFile,'records','summary','windowStatistics', ...
    'experiment','config','schedule','replayOptions', ...
    'figureManifest','options');

report = struct('outputFolder',outputFolder, ...
    'summary',summary,'windowStatistics',windowStatistics, ...
    'figureManifest',figureManifest,'summaryCsv',summaryCsv, ...
    'windowCsv',windowCsv,'mappingCsv',mappingCsv, ...
    'manifestCsv',manifestCsv,'matFile',matFile);
fprintf('Fuxian Stage55 report complete: %s\n',outputFolder);
disp(summary(:,{'snrDb','region','method','ser','deliveredBer'}));
end
