function report = plot_stage55_senlora_prec_ser_ber_trajectory(options)
%PLOT_STAGE55_SENLORA_PREC_SER_BER_TRAJECTORY Plot the fair two-method result.
%   Replots the saved Stage55 fair replay without rerunning the simulation.
%   Each orbit-region figure contains the Doppler shift/rate context and
%   only two performance metrics: SER and post-FEC delivered BER.  The
%   performance curves contain only Huang-PREC-CP and SenLoRa.

arguments
    options.ReportMatFile (1,:) char = fullfile(fileparts( ...
        mfilename('fullpath')),'results', ...
        'stage55_huang_prec_cp_fair_comparison_20260812', ...
        'stage55_fresh_three_method_overall_report.mat')
    options.OutputFolderName (1,:) char = ...
        'stage55_senlora_prec_ser_ber_trajectory_20260813'
end

if ~isfile(options.ReportMatFile)
    error('SatelliteFig3:TwoMethodPlotInput', ...
        'Fair-comparison report not found: %s',options.ReportMatFile);
end

requiredVariables = {'config','schedule','records','summary', ...
    'windowStatistics'};
source = load(options.ReportMatFile,requiredVariables{:});
for index = 1:numel(requiredVariables)
    if ~isfield(source,requiredVariables{index})
        error('SatelliteFig3:TwoMethodPlotField', ...
            'Source report is missing %s.',requiredVariables{index});
    end
end

sourceMethods = {'Huang-PREC-CP','Stage55-VP-quality'};
displayLabels = {'PREC (Huang)','SenLoRa'};
localValidateSource(source,sourceMethods);

selectedWindowStatistics = source.windowStatistics(ismember( ...
    string(source.windowStatistics.method),string(sourceMethods)),:);
selectedRecords = source.records(ismember( ...
    string(source.records.method),string(sourceMethods)),:);
selectedSummary = source.summary(ismember( ...
    string(source.summary.method),string(sourceMethods)),:);

windowVariables = {'snrDb','region','method','windowIndex', ...
    'windowStartTimeSec','windowCenterTimeSec','windowEndTimeSec', ...
    'frameCount','symbolCount','symbolErrors','ser','serShown', ...
    'serLower95','serUpper95','bitCount','deliveredBitErrors', ...
    'deliveredBer','deliveredBerShown','deliveredBerLower95', ...
    'deliveredBerUpper95'};
summaryVariables = {'snrDb','region','method','frameCount', ...
    'symbolCount','symbolErrors','ser','serShown','bitCount', ...
    'deliveredBitErrors','deliveredBer','deliveredBerShown', ...
    'independentPassCount','serPassMean','serPassCi95Lower', ...
    'serPassCi95Upper','deliveredBerPassMean', ...
    'deliveredBerPassCi95Lower','deliveredBerPassCi95Upper'};
selectedWindowStatistics = selectedWindowStatistics(:,windowVariables);
selectedSummary = selectedSummary(:,summaryVariables);

root = fileparts(mfilename('fullpath'));
outputFolder = fullfile(root,'results',options.OutputFolderName);
if ~isfolder(outputFolder)
    mkdir(outputFolder);
end

windowCsvFile = fullfile(outputFolder, ...
    'stage55_senlora_prec_window_ser_ber_statistics.csv');
summaryCsvFile = fullfile(outputFolder, ...
    'stage55_senlora_prec_region_ser_ber_summary.csv');
mappingCsvFile = fullfile(outputFolder, ...
    'stage55_senlora_prec_method_mapping.csv');
writetable(selectedWindowStatistics,windowCsvFile);
writetable(selectedSummary,summaryCsvFile);
mapping = table(string(sourceMethods(:)),string(displayLabels(:)), ...
    ["Huang thesis PREC replay";"Stage55 VP-quality receiver"], ...
    'VariableNames',{'sourceMethod','plotLabel','role'});
writetable(mapping,mappingCsvFile);

snrGridDb = unique(selectedWindowStatistics.snrDb,'stable').';
regionKeys = {'high_doppler_rate','high_doppler_shift'};
figureRecords = repmat(struct('snrDb',NaN,'region','', ...
    'pngFile','','pdfFile','','figFile',''), ...
    numel(snrGridDb)*numel(regionKeys),1);
recordIndex = 0;
for snrIndex = 1:numel(snrGridDb)
    for regionIndex = 1:numel(regionKeys)
        recordIndex = recordIndex+1;
        figureRecords(recordIndex) = localPlotOrbitRegion(outputFolder, ...
            selectedWindowStatistics,selectedRecords,source.config, ...
            source.schedule,snrGridDb(snrIndex), ...
            regionKeys{regionIndex},sourceMethods,displayLabels);
    end
end
figureManifest = struct2table(figureRecords);
manifestCsvFile = fullfile(outputFolder, ...
    'stage55_senlora_prec_ser_ber_figure_manifest.csv');
writetable(figureManifest,manifestCsvFile);

sourceReportMatFile = options.ReportMatFile;
matFile = fullfile(outputFolder, ...
    'stage55_senlora_prec_ser_ber_trajectory_report.mat');
config = source.config;
schedule = source.schedule;
save(matFile,'config','schedule','selectedRecords', ...
    'selectedWindowStatistics','selectedSummary','mapping', ...
    'figureManifest','sourceReportMatFile','options');

report = struct('outputFolder',outputFolder, ...
    'selectedWindowStatistics',selectedWindowStatistics, ...
    'selectedSummary',selectedSummary,'mapping',mapping, ...
    'figureManifest',figureManifest,'windowCsvFile',windowCsvFile, ...
    'summaryCsvFile',summaryCsvFile,'mappingCsvFile',mappingCsvFile, ...
    'manifestCsvFile',manifestCsvFile,'matFile',matFile);
fprintf('Stage55 SenLoRa/PREC SER-BER trajectory plots complete: %s\n', ...
    outputFolder);
end

function localValidateSource(source,methods)
availableWindowMethods = unique(string(source.windowStatistics.method));
availableRecordMethods = unique(string(source.records.method));
availableSummaryMethods = unique(string(source.summary.method));
if ~all(ismember(string(methods),availableWindowMethods)) || ...
        ~all(ismember(string(methods),availableRecordMethods)) || ...
        ~all(ismember(string(methods),availableSummaryMethods))
    error('SatelliteFig3:TwoMethodPlotMethods', ...
        'The saved report does not contain both fair-comparison methods.');
end

snrGridDb = unique(source.windowStatistics.snrDb,'stable');
regions = {'high_doppler_rate','high_doppler_shift'};
for snrIndex = 1:numel(snrGridDb)
    for regionIndex = 1:numel(regions)
        referenceRows = localWindowRows(source.windowStatistics, ...
            snrGridDb(snrIndex),regions{regionIndex},methods{1});
        senLoRaRows = localWindowRows(source.windowStatistics, ...
            snrGridDb(snrIndex),regions{regionIndex},methods{2});
        if isempty(referenceRows) || height(referenceRows) ~= height(senLoRaRows)
            error('SatelliteFig3:TwoMethodPlotWindows', ...
                'The two methods do not have the same window ledger.');
        end
        if ~isequal(referenceRows.windowIndex,senLoRaRows.windowIndex) || ...
                ~isequal(referenceRows.windowStartTimeSec, ...
                    senLoRaRows.windowStartTimeSec) || ...
                ~isequal(referenceRows.windowEndTimeSec, ...
                    senLoRaRows.windowEndTimeSec) || ...
                ~isequal(referenceRows.frameCount,senLoRaRows.frameCount)
            error('SatelliteFig3:TwoMethodPlotLedger', ...
                'The two methods do not share identical plotting windows.');
        end
    end
end
end

function record = localPlotOrbitRegion(folder,windowTable,records,config, ...
        schedule,snrDb,regionKey,methods,labels)
colors = [0.84 0.18 0.13;0.00 0.38 0.78];
styles = {'s--','o-'};
selectedRegion = records.snrDb == snrDb & ...
    strcmp(records.region,regionKey) & strcmp(records.method,methods{1});
if ~any(selectedRegion)
    error('SatelliteFig3:TwoMethodPlotRegion', ...
        'No records found for %.1f dB, %s.',snrDb,regionKey);
end
targetIntervals = localRegionIntervals( ...
    unique(records.frameIndex(selectedRegion)),schedule);

denseTime = linspace(schedule.passStartTimeSec, ...
    schedule.passEndTimeSec,1600).';
trajectory = satelliteFig3Trajectory(denseTime,config);
fig = figure('Visible','off','Color','w','Position',[40 20 1680 1280]);
layout = tiledlayout(fig,4,1,'TileSpacing','compact','Padding','compact');

ax1 = nexttile(layout);
hold(ax1,'on');
plot(ax1,denseTime,trajectory.dopplerShiftHz/1e3, ...
    'Color',[0 0.45 0.74],'LineWidth',1.5);
ylabel(ax1,'Shift (kHz)');
ylim(ax1,[-20 20]);
grid(ax1,'on');
title(ax1,['(a) ' localRegionTitle(regionKey,records, ...
    selectedRegion,config)],'FontWeight','normal');
localBlindLines(ax1,schedule.window);
localTargetLines(ax1,targetIntervals);

ax2 = nexttile(layout);
hold(ax2,'on');
plot(ax2,denseTime,trajectory.dopplerRateHzPerSec, ...
    'Color',[0.85 0.33 0.10],'LineWidth',1.5);
ylabel(ax2,'Rate (Hz/s)');
ylim(ax2,[-250 0]);
grid(ax2,'on');
title(ax2,'(b) Orbit Doppler-rate trajectory','FontWeight','normal');
localBlindLines(ax2,schedule.window);
localTargetLines(ax2,targetIntervals);

plotSpecs = { ...
    'serShown','serLower95','serUpper95','Window SER', ...
        '(c) Symbol error rate (95% interval)',[1e-5 1]; ...
    'deliveredBerShown','deliveredBerLower95','deliveredBerUpper95', ...
        'Window BER','(d) BER after common ML-soft Hamming (95% interval)', ...
        [1e-5 1]};
axesList = [ax1 ax2];
for panelIndex = 1:size(plotSpecs,1)
    ax = nexttile(layout);
    hold(ax,'on');
    set(ax,'YScale','log');
    for methodIndex = 1:numel(methods)
        rows = localWindowRows(windowTable,snrDb,regionKey, ...
            methods{methodIndex});
        lower = max(rows.(plotSpecs{panelIndex,2}), ...
            plotSpecs{panelIndex,6}(1));
        upper = max(rows.(plotSpecs{panelIndex,3}), ...
            plotSpecs{panelIndex,6}(1));
        localBand(ax,rows.windowCenterTimeSec,lower,upper, ...
            colors(methodIndex,:));
    end
    for methodIndex = 1:numel(methods)
        rows = localWindowRows(windowTable,snrDb,regionKey, ...
            methods{methodIndex});
        plot(ax,rows.windowCenterTimeSec, ...
            rows.(plotSpecs{panelIndex,1}),styles{methodIndex}, ...
            'Color',colors(methodIndex,:),'LineWidth',1.5, ...
            'MarkerSize',4.5,'DisplayName',labels{methodIndex});
    end
    ylabel(ax,plotSpecs{panelIndex,4});
    ylim(ax,plotSpecs{panelIndex,6});
    grid(ax,'on');
    grid(ax,'minor');
    box(ax,'on');
    title(ax,plotSpecs{panelIndex,5},'FontWeight','normal');
    localShadeBlind(ax,schedule.window);
    localTargetLines(ax,targetIntervals);
    legend(ax,'Location','best','FontSize',9,'Box','on');
    axesList(end+1) = ax; %#ok<AGROW>
end
xlabel(axesList(end),'Time relative to closest approach (s)');

for index = 1:numel(axesList)
    xlim(axesList(index), ...
        [schedule.passStartTimeSec schedule.passEndTimeSec]);
    set(axesList(index),'FontName','Times New Roman','FontSize',10, ...
        'GridLineStyle',':','MinorGridLineStyle',':');
end
linkaxes(axesList,'x');
sgtitle(layout,sprintf([ ...
    'Stage55 fair Doppler-trajectory comparison: %.1f dB, %s\n' ...
    'PREC and SenLoRa only; same frame ledger, payload, noise, and decoder'], ...
    snrDb,strrep(regionKey,'_',' ')), ...
    'FontWeight','normal','FontSize',14);

base = sprintf('stage55_senlora_prec_ser_ber_%s_%s_dB', ...
    regionKey,localSnrToken(snrDb));
pngFile = fullfile(folder,[base '.png']);
pdfFile = fullfile(folder,[base '.pdf']);
figFile = fullfile(folder,[base '.fig']);
exportgraphics(fig,pngFile,'Resolution',220);
exportgraphics(fig,pdfFile,'ContentType','vector');
savefig(fig,figFile);
close(fig);
record = struct('snrDb',snrDb,'region',regionKey, ...
    'pngFile',pngFile,'pdfFile',pdfFile,'figFile',figFile);
end

function rows = localWindowRows(tableIn,snrDb,region,method)
rows = tableIn(tableIn.snrDb == snrDb & strcmp(tableIn.region,region) & ...
    strcmp(tableIn.method,method),:);
rows = sortrows(rows,'windowIndex');
end

function titleText = localRegionTitle(regionKey,records,selected,config)
trajectory = satelliteFig3Trajectory(records.frameCenterTimeSec(selected), ...
    config);
if strcmp(regionKey,'high_doppler_rate')
    titleText = sprintf( ...
        'High Doppler-rate region: |rate| %.1f--%.1f Hz/s', ...
        min(abs(trajectory.dopplerRateHzPerSec)), ...
        max(abs(trajectory.dopplerRateHzPerSec)));
else
    titleText = sprintf( ...
        'High Doppler-shift region: |shift| %.1f--%.1f kHz', ...
        min(abs(trajectory.dopplerShiftHz))/1e3, ...
        max(abs(trajectory.dopplerShiftHz))/1e3);
end
end

function intervals = localRegionIntervals(frameIndices,schedule)
mask = false(schedule.frameCount,1);
mask(frameIndices) = true;
starts = find(mask & [true;~mask(1:end-1)]);
ends = find(mask & [~mask(2:end);true]);
intervals = [schedule.frameStartTimeSec(starts), ...
    schedule.frameEndTimeSec(ends)];
end

function localBand(ax,x,lower,upper,color)
valid = isfinite(x) & isfinite(lower) & isfinite(upper) & upper >= lower;
starts = find(valid & [true;~valid(1:end-1)]);
ends = find(valid & [~valid(2:end);true]);
for segment = 1:numel(starts)
    index = starts(segment):ends(segment);
    patch(ax,[x(index);flipud(x(index))], ...
        [lower(index);flipud(upper(index))],color, ...
        'FaceAlpha',0.07,'EdgeColor','none','HandleVisibility','off');
end
end

function localShadeBlind(ax,window)
hold(ax,'on');
limits = ylim(ax);
blind = window.blindIntervalSec;
patch(ax,[blind(1) blind(2) blind(2) blind(1)], ...
    [limits(1) limits(1) limits(2) limits(2)],[0.88 0.88 0.88], ...
    'FaceAlpha',0.25,'EdgeColor','none','HandleVisibility','off');
localBlindLines(ax,window);
ylim(ax,limits);
end

function localBlindLines(ax,window)
xline(ax,window.blindIntervalSec(1),'Color',[0.45 0.45 0.45], ...
    'LineStyle',':','HandleVisibility','off');
xline(ax,window.blindIntervalSec(2),'Color',[0.45 0.45 0.45], ...
    'LineStyle',':','HandleVisibility','off');
end

function localTargetLines(ax,intervals)
for index = 1:size(intervals,1)
    xline(ax,intervals(index,1),'Color',[0.20 0.55 0.20], ...
        'LineStyle','--','LineWidth',0.7,'HandleVisibility','off');
    xline(ax,intervals(index,2),'Color',[0.20 0.55 0.20], ...
        'LineStyle','--','LineWidth',0.7,'HandleVisibility','off');
end
end

function token = localSnrToken(snrDb)
token = strrep(sprintf('%g',snrDb),'-','minus');
end
