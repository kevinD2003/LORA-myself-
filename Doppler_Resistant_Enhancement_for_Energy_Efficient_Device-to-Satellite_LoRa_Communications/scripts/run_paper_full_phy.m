function result = run_paper_full_phy(options)
%RUN_PAPER_FULL_PHY Reproduce Figs. 3-4 and Tables V-VI for CR1 and CR4.

arguments
    options.Overpasses (1,1) double {mustBeInteger,mustBePositive} = 3000
    options.MaximumPackets (1,1) double {mustBePositive} = inf
    options.CalibrationSamplesPerSnr (1,1) double {mustBeInteger,mustBePositive} = 5000
    options.SnrDb (:,1) double = [0;-5;-10;-15;-20]
end
root = dreSetupPaths(false);
config = dreFullPhyConfig();
config.fullPhyOverpasses = options.Overpasses;
config.maximumPackets = options.MaximumPackets;
config.calibrationSamplesPerSnr = options.CalibrationSamplesPerSnr;
config.snrDb = options.SnrDb;
signature = dreConfigurationSignature(config);
output = fullfile(root,'results','paper_full_phy');
if ~isfolder(output), mkdir(output); end
matPath = fullfile(output,'full_phy_run.mat');
if isfile(matPath)
    existing = load(matPath,'result');
    if isfield(existing,'result') && strcmp(existing.result.signature,signature)
        result = existing.result;
        result.table = localBuildTable(result.conditions,config);
        result.config = config;
        save(matPath,'result','-v7.3');
        localWriteSidecars(result.table,result.conditions,config,output);
        fprintf('Reusing full-PHY result with matching signature.\n');
        return
    end
end
calibration = cell(numel(config.snrDb),1);
for snrIndex = 1:numel(config.snrDb)
    calibration{snrIndex} = dreCalibrateCentroidErrors(config.snrDb(snrIndex), ...
        config,config.calibrationSamplesPerSnr, ...
        config.randomSeed+700000+snrIndex);
    fprintf('Centroid calibration SNR %+g dB: RMS %.4g bins (%d samples)\n', ...
        config.snrDb(snrIndex),calibration{snrIndex}.rmsBins, ...
        calibration{snrIndex}.sampleCount);
end
conditionCount = numel(config.crValues)*numel(config.snrDb);
conditionCells = cell(conditionCount,1);
row = 0;
for crIndex = 1:numel(config.crValues)
    for snrIndex = 1:numel(config.snrDb)
        row = row+1;
        conditionCells{row} = dreRunFullPhyCondition(config.crValues(crIndex), ...
            config.snrDb(snrIndex),config,calibration{snrIndex}, ...
            config.fullPhyOverpasses,config.maximumPackets);
    end
end
conditions = vertcat(conditionCells{:});
tableOut = localBuildTable(conditions,config);
isFormal = config.fullPhyOverpasses==3000 && isinf(config.maximumPackets) && ...
    isequal(config.snrDb(:),[0;-5;-10;-15;-20]);
status = 'SMOKE';
if isFormal, status = 'COMPLETE'; end
result = struct('status',status,'signature',signature,'config',config, ...
    'calibration',{calibration},'conditions',{conditions},'table',tableOut, ...
    'paperSource','WSA 2025 Figures 3-4 and Tables V-VI', ...
    'receiverUsesPayloadTruth',false,'fullPhyImplemented',true);
localWriteSidecars(tableOut,conditions,config,output);
save(matPath,'result','-v7.3');
end

function tableOut = localBuildTable(conditions,config)
n = numel(conditions);
cr = zeros(n,1); snrDb = zeros(n,1); packetCount = zeros(n,1);
packetSymbolCount = zeros(n,1); overpasses = zeros(n,1);
adaptiveBerPercent = zeros(n,1); adaptivePlrPercent = zeros(n,1);
fixedBerPercent = zeros(n,1); fixedPlrPercent = zeros(n,1);
adaptiveCrcFilteredBerPercent = zeros(n,1);
fixedCrcFilteredBerPercent = zeros(n,1);
paperAdaptiveBerPercent = zeros(n,1); paperAdaptivePlrPercent = zeros(n,1);
paperFixedBerPercent = zeros(n,1); paperFixedPlrPercent = zeros(n,1);
for row = 1:n
    c = conditions(row); cr(row)=c.cr; snrDb(row)=c.snrDb;
    packetCount(row)=c.packetCount; packetSymbolCount(row)=c.packetSymbolCount;
    overpasses(row)=c.overpasses;
    adaptiveBerPercent(row)=100*c.codedBer(1); fixedBerPercent(row)=100*c.codedBer(2);
    adaptiveCrcFilteredBerPercent(row)=100*c.crcFilteredCodedBer(1);
    fixedCrcFilteredBerPercent(row)=100*c.crcFilteredCodedBer(2);
    adaptivePlrPercent(row)=100*c.plr(1); fixedPlrPercent(row)=100*c.plr(2);
    index = find([0 -5 -10 -15 -20]==c.snrDb,1);
    if c.cr==1
        paperAdaptiveBerPercent(row)=config.paperCr1AdaptiveBerPercent(index);
        paperAdaptivePlrPercent(row)=config.paperCr1AdaptivePlrPercent(index);
        paperFixedBerPercent(row)=config.paperCr1FixedBerPercent(index);
        paperFixedPlrPercent(row)=config.paperCr1FixedPlrPercent(index);
    else
        paperAdaptiveBerPercent(row)=config.paperCr4AdaptiveBerPercent(index);
        paperAdaptivePlrPercent(row)=config.paperCr4AdaptivePlrPercent(index);
        paperFixedBerPercent(row)=config.paperCr4FixedBerPercent(index);
        paperFixedPlrPercent(row)=config.paperCr4FixedPlrPercent(index);
    end
end
tableOut = table(cr,snrDb,packetCount,packetSymbolCount,overpasses, ...
    adaptiveBerPercent,paperAdaptiveBerPercent, ...
    adaptiveBerPercent-paperAdaptiveBerPercent, ...
    adaptiveCrcFilteredBerPercent, ...
    adaptivePlrPercent,paperAdaptivePlrPercent, ...
    adaptivePlrPercent-paperAdaptivePlrPercent, ...
    fixedBerPercent,paperFixedBerPercent,fixedBerPercent-paperFixedBerPercent, ...
    fixedCrcFilteredBerPercent, ...
    fixedPlrPercent,paperFixedPlrPercent,fixedPlrPercent-paperFixedPlrPercent, ...
    'VariableNames',{'cr','snrDb','packetCount','packetSymbolCount','overpasses', ...
    'adaptiveBerPercent','paperAdaptiveBerPercent','adaptiveBerDeltaPoints', ...
    'adaptiveCrcFilteredBerPercent', ...
    'adaptivePlrPercent','paperAdaptivePlrPercent','adaptivePlrDeltaPoints', ...
    'fixedBerPercent','paperFixedBerPercent','fixedBerDeltaPoints', ...
    'fixedCrcFilteredBerPercent', ...
    'fixedPlrPercent','paperFixedPlrPercent','fixedPlrDeltaPoints'});
end

function localWriteSidecars(tableOut,conditions,config,output)
writetable(tableOut,fullfile(output,'full_phy_tables.csv'));
for cr = config.crValues
    conditionIndex = find([conditions.cr]==cr & [conditions.snrDb]==-10,1);
    if isempty(conditionIndex), continue, end
    c = conditions(conditionIndex);
    figure('Visible','off','Color','w','Position',[100 100 900 500]);
    yyaxis left;
    semilogy(0:c.packetCount-1,max(c.trajectoryBer(:,1),1e-5), ...
        '-','LineWidth',1.4); hold on;
    semilogy(0:c.packetCount-1,max(c.trajectoryBer(:,2),1e-5), ...
        '--','LineWidth',1.2);
    ylabel('coded BER'); ylim([1e-5 1]); grid on;
    yyaxis right;
    plot(0:c.packetCount-1,c.dopplerHz/1e3,'-','LineWidth',1.2);
    ylabel('Doppler frequency (kHz)');
    xlabel('packet index');
    title(sprintf('Full-PHY reproduction, CR=%d, SNR=-10 dB, %d overpasses', ...
        cr,c.overpasses));
    legend('Adaptive LR','Fixed LR','Doppler frequency','Location','best');
    figureNumber = 3+(cr==4);
    exportgraphics(gcf,fullfile(output,sprintf('figure_%d_cr%d_ber_trajectory.png', ...
        figureNumber,cr)),'Resolution',180);
    close(gcf);
end
end
