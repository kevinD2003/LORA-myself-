function report = run_ideal_ser_experiment()
%RUN_IDEAL_SER_EXPERIMENT Generate the independent common ideal SER bound.

close all;
here = fileparts(mfilename('fullpath'));
addpath(here);
config = ideal_ser_config();
if ~isfolder(config.outputFolder),mkdir(config.outputFolder),end

addpath(fullfile(config.stage55Root,'config'));
addpath(genpath(fullfile(config.stage55Root,'src','coding')));
addpath(genpath(fullfile(config.stage55Root,'src','phy')));
addpath(genpath(fullfile(config.stage55Root,'src','paper_anchor')));
addpath(fullfile(config.stage55Root,'src','infrastructure'));
stageConfig = sf12NoLdroSf11FlowConfig();

fprintf('Computing exact ideal SER curve directly by quadrature...\n');
curveSer = theoretical_lora_ser(config.sf,config.snrCurveDb, ...
    RelTol=config.theoryRelTol,AbsTol=config.theoryAbsTol);
anchorSer = theoretical_lora_ser(config.sf,config.snrAnchorDb, ...
    RelTol=config.theoryRelTol,AbsTol=config.theoryAbsTol);
isStage55Anchor = ismember(config.snrCurveDb,config.snrAnchorDb);
theoryCurve = table(config.snrCurveDb,curveSer,isStage55Anchor, ...
    'VariableNames',{'snrDb','ser','isStage55Anchor'});

fprintf('Running fresh Case A/B full-waveform validation...\n');
[monteCarlo,audit] = simulate_ideal_compensation( ...
    config,stageConfig,anchorSer);
validation = validate_ideal_ser( ...
    config,stageConfig,theoryCurve,monteCarlo,audit);

curveCsv = fullfile(config.outputFolder,'ideal_ser_theory.csv');
validationCsv = fullfile(config.outputFolder,'ideal_ser_validation.csv');
writetable(theoryCurve,curveCsv);
writetable(monteCarlo,validationCsv);

figureHandle = figure('Visible','off','Color','w', ...
    'Position',[100 100 980 650]);
axesHandle = axes(figureHandle);
semilogy(axesHandle,theoryCurve.snrDb,theoryCurve.ser, ...
    '-','Color',[0 0.4470 0.7410],'LineWidth',2.2, ...
    'DisplayName','Ideal Doppler Compensation - Theoretical SER');
hold(axesHandle,'on');
anchorRows = theoryCurve.isStage55Anchor;
semilogy(axesHandle,theoryCurve.snrDb(anchorRows), ...
    theoryCurve.ser(anchorRows),'o','LineStyle','none', ...
    'Color',[0 0.4470 0.7410],'MarkerFaceColor','w', ...
    'MarkerSize',6,'HandleVisibility','off');
grid(axesHandle,'on');grid(axesHandle,'minor');
xlabel(axesHandle,'SNR (dB)');ylabel(axesHandle,'SER');
title(axesHandle,{ ...
    'SF12 LoRa ideal Doppler-compensation SER', ...
    'Common theoretical boundary for Case A and Case B'});
xlim(axesHandle,[config.snrCurveDb(1) config.snrCurveDb(end)]);
minimum = min(theoryCurve.ser(theoryCurve.ser>0));
ylim(axesHandle,[10^floor(log10(minimum)) 1]);
legend(axesHandle,'Location','southwest');
axesHandle.FontSize = 11;axesHandle.LineWidth = 1;

pngPath = fullfile(config.outputFolder,'ideal_ser.png');
pdfPath = fullfile(config.outputFolder,'ideal_ser.pdf');
figPath = fullfile(config.outputFolder,'ideal_ser.fig');
exportgraphics(figureHandle,pngPath,'Resolution',300);
exportgraphics(figureHandle,pdfPath,'ContentType','vector');
savefig(figureHandle,figPath);close(figureHandle);

sourceManifest = localSourceManifest(config);
metadata = struct('identity',config.identity, ...
    'generatedAt',char(datetime('now','Format','yyyy-MM-dd''T''HH:mm:ssXXX')), ...
    'matlabVersion',version,'configuration',config, ...
    'stage55PhysicalConfiguration',localPhysicalConfig(stageConfig), ...
    'sourceManifest',{sourceManifest}, ...
    'performanceDataInputs',config.performanceDataInputs, ...
    'fittedToFrozenData',false,'existingPerformanceDataLoaded',false, ...
    'curveSource',config.curveSource, ...
    'validationStatus',validation.status);
metadataPath = fullfile(config.outputFolder,'ideal_ser_metadata.json');
localWriteText(metadataPath,jsonencode(metadata,'PrettyPrint',true));

matPath = fullfile(config.outputFolder,'ideal_ser_theory.mat');
save(matPath,'theoryCurve','monteCarlo','audit','validation', ...
    'metadata','config','-v7.3');
reportPath = fullfile(config.outputFolder,'ideal_ser_report.md');
localWriteReport(reportPath,config,theoryCurve,monteCarlo,audit,validation);

report = struct('status',validation.status,'curveCsv',curveCsv, ...
    'validationCsv',validationCsv,'metadataJson',metadataPath, ...
    'matPath',matPath,'reportPath',reportPath,'pngPath',pngPath, ...
    'pdfPath',pdfPath,'figPath',figPath, ...
    'fittedToFrozenData',false);
fprintf('Ideal SER experiment status: %s\n',report.status);
fprintf('Figure: %s\n',report.pngPath);
if ~strcmp(validation.status,'PASS')
    error('IdealSER:ValidationFailed','One or more acceptance checks failed.');
end
end

function manifest = localSourceManifest(config)
paths = [{fullfile(fileparts(mfilename('fullpath')), ...
    'run_ideal_ser_experiment.m')}; ...
    {fullfile(fileparts(mfilename('fullpath')),'ideal_ser_config.m')}; ...
    {fullfile(fileparts(mfilename('fullpath')),'theoretical_lora_ser.m')}; ...
    {fullfile(fileparts(mfilename('fullpath')),'simulate_ideal_compensation.m')}; ...
    {fullfile(fileparts(mfilename('fullpath')),'validate_ideal_ser.m')}];
for index = 1:numel(config.stage55SourceFiles)
    paths{end+1,1} = fullfile(config.stage55Root, ...
        strrep(config.stage55SourceFiles{index},'/',filesep)); %#ok<AGROW>
end
manifest = repmat(struct('path','','sha256',''),numel(paths),1);
for index = 1:numel(paths)
    if contains(lower(paths{index}),[filesep 'results' filesep])
        error('IdealSER:ForbiddenInput','Performance result input is forbidden.');
    end
    manifest(index).path = paths{index};
    manifest(index).sha256 = v4Sha256(paths{index});
end
end

function physical = localPhysicalConfig(c)
physical = struct('physicalSf',c.physicalSf, ...
    'effectiveDataSf',c.effectiveDataSf,'bandwidthHz',c.bandwidthHz, ...
    'sampleRateHz',c.sampleRateHz, ...
    'carrierFrequencyHz',c.carrierFrequencyHz, ...
    'samplesPerSymbol',c.samplesPerSymbol, ...
    'symbolDurationSec',c.symbolDurationSec, ...
    'fftBinSpacingHz',c.fftBinSpacingHz,'cr',c.cr, ...
    'payloadSymbolCount',c.payloadSymbolCount, ...
    'informationBitCount',c.informationBitCount, ...
    'bootstrapPilotCount',c.bootstrapPilotCount, ...
    'paperMidambleInterval',c.paperMidambleInterval, ...
    'paperMidambleCount',c.paperMidambleCount, ...
    'commonTimelineSymbolCount',c.commonTimelineSymbolCount, ...
    'ricianApplied',false);
end

function localWriteText(path,text)
file = fopen(path,'w','n','UTF-8');
if file<0,error('IdealSER:Write','Cannot write %s.',path),end
cleaner = onCleanup(@()fclose(file));
fprintf(file,'%s\n',text);clear cleaner
end

function localWriteReport(path,config,theory,mc,audit,validation)
file = fopen(path,'w','n','UTF-8');
if file<0,error('IdealSER:Write','Cannot write %s.',path),end
cleaner = onCleanup(@()fclose(file));
fprintf(file,'# Ideal Stage55-condition SER experiment\n\n');
fprintf(file,'Status: **%s**\n\n',validation.status);
fprintf(file,'- One common exact SER curve for Case A and Case B.\n');
fprintf(file,'- SF12, BW/Fs 125 kHz, Fc 868 MHz, no-LDRO, CR3.\n');
fprintf(file,'- 8 bootstrap + 112 payload + 37 midamble = 157 symbols.\n');
fprintf(file,'- Channel: continuous deterministic LEO Doppler plus complex AWGN.\n');
fprintf(file,'- Compensation: exact samplewise inverse Doppler phase.\n');
fprintf(file,'- Theory: direct quadrature at every plotted point; no fit.\n');
fprintf(file,'- Frozen performance data loaded: `false`.\n');
fprintf(file,'- Fresh validation: %d packets per Case/SNR.\n\n', ...
    config.validationPacketsPerCaseSnr);
fprintf(file,'Case A initial/final Doppler: %.6f / %.6f Hz.\n\n', ...
    audit.caseAudit(1).initialDopplerHz,audit.caseAudit(1).finalDopplerHz);
fprintf(file,'Case B initial/final Doppler: %.6f / %.6f Hz.\n\n', ...
    audit.caseAudit(2).initialDopplerHz,audit.caseAudit(2).finalDopplerHz);
fprintf(file,'Theory range: %.12g to %.12g.\n\n', ...
    max(theory.ser),min(theory.ser));
fprintf(file,'Total validation symbols: %.0f.\n',sum(mc.symbolCount));
clear cleaner
end
