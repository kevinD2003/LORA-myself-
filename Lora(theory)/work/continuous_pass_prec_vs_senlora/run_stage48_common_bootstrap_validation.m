function report = run_stage48_common_bootstrap_validation(options)
%RUN_STAGE48_COMMON_BOOTSTRAP_VALIDATION Noiseless mechanism inspection.
%   This is not a BER experiment.  It verifies that the static Huang-PREC
%   baseline and SenLoRa use the same Huang CFO estimate while only
%   SenLoRa uses known-preamble rate and causal virtual-pilot updates.

arguments
    options.SampleSnrDb (1,1) double = Inf
    options.PayloadSeed (1,1) double = 2026120101
    options.NoiseSeed (1,1) double = 2026120102
    options.OutputFolderName (1,:) char = ...
        'stage48_common_bootstrap_validation'
end

root = fileparts(mfilename('fullpath'));
resultDir = fullfile(root,'results',options.OutputFolderName);
if ~isfolder(resultDir), mkdir(resultDir); end
config = satelliteFig3Config();
[window,~] = satelliteFig3VisibilityWindow(config);
scenarioKeys = {'high_doppler_shift','high_doppler_rate'};
scenarioTitles = {'High Doppler shift','High Doppler rate'};
startTimes = [-window.deltaTimeOutSec,window.deltaTimeInSec];
known = zeros(config.bootstrapPilotCount,1);
payload = satelliteFig3GeneratePayload(config,options.PayloadSeed);
labels = [known;payload.symbolBins];
payloadRows = (config.bootstrapPilotCount+1:config.frameSymbolCount).';
payloadTimeSec = (payloadRows-0.5)*config.symbolDurationSec;
sceneCount = numel(startTimes);

trueCfoBins = zeros(config.payloadSymbolCount,sceneCount);
trueRateBinsPerSec = zeros(config.payloadSymbolCount,sceneCount);
staticCfoBins = zeros(config.payloadSymbolCount,sceneCount);
senCfoBins = zeros(config.payloadSymbolCount,sceneCount);
senRateBinsPerSec = zeros(config.payloadSymbolCount,sceneCount);
senAccepted = false(config.payloadSymbolCount,sceneCount);
initialCfoBins = zeros(sceneCount,1);
initialRateBinsPerSec = zeros(sceneCount,1);
staticRmseBins = zeros(sceneCount,1);
senRmseBins = zeros(sceneCount,1);

for scene = 1:sceneCount
    [rx,~,truth] = generateContinuousSatelliteFrame(labels,config, ...
        StartTimeSec=startTimes(scene), ...
        SampleSnrDb=options.SampleSnrDb, ...
        NoiseSeed=options.NoiseSeed);
    staticPrec = satelliteFig3HuangPrecStaticCpDecode(rx,config,known);
    senlora = satelliteFig3SenLoRaVirtualPilotDecode(rx,config,known);

    if ~isequaln(staticPrec.bootstrap,senlora.commonBootstrap)
        error('SatelliteFig3:Stage48BootstrapMismatch', ...
            'The two algorithms did not share an identical bootstrap.');
    end
    trueCfoBins(:,scene) = truth.trueDopplerHz(payloadRows)/ ...
        config.fftBinSpacingHz;
    trueRateBinsPerSec(:,scene) = ...
        truth.trueDopplerRateHzPerSec(payloadRows)/ ...
        config.fftBinSpacingHz;
    staticCfoBins(:,scene) = ...
        staticPrec.tracker.predictedCfoBins(payloadRows);
    senCfoBins(:,scene) = senlora.tracker.predictedCfoBins(payloadRows);
    senRateBinsPerSec(:,scene) = ...
        senlora.tracker.predictedRateBinsPerSec(payloadRows);
    senAccepted(:,scene) = senlora.pilotAccepted(payloadRows);
    initialCfoBins(scene) = staticPrec.bootstrap.epsilonHatBins;
    initialRateBinsPerSec(scene) = senlora.initialRateBinsPerSec;
    staticRmseBins(scene) = sqrt(mean(( ...
        staticCfoBins(:,scene)-trueCfoBins(:,scene)).^2));
    senRmseBins(scene) = sqrt(mean(( ...
        senCfoBins(:,scene)-trueCfoBins(:,scene)).^2));
end

rowCount = config.payloadSymbolCount*sceneCount;
scenario = cell(rowCount,1);
orbitStartSec = zeros(rowCount,1);
payloadSymbol = zeros(rowCount,1);
frameTimeSec = zeros(rowCount,1);
trueCfo = zeros(rowCount,1);
staticCfo = zeros(rowCount,1);
senCfo = zeros(rowCount,1);
staticResidual = zeros(rowCount,1);
senResidual = zeros(rowCount,1);
trueRate = zeros(rowCount,1);
senRate = zeros(rowCount,1);
accepted = false(rowCount,1);
cursor = 0;
for sceneIndex = 1:sceneCount
    rows = cursor+(1:config.payloadSymbolCount);
    scenario(rows) = repmat(scenarioKeys(sceneIndex), ...
        config.payloadSymbolCount,1);
    orbitStartSec(rows) = startTimes(sceneIndex);
    payloadSymbol(rows) = (1:config.payloadSymbolCount).';
    frameTimeSec(rows) = payloadTimeSec;
    trueCfo(rows) = trueCfoBins(:,sceneIndex);
    staticCfo(rows) = staticCfoBins(:,sceneIndex);
    senCfo(rows) = senCfoBins(:,sceneIndex);
    staticResidual(rows) = staticCfoBins(:,sceneIndex)- ...
        trueCfoBins(:,sceneIndex);
    senResidual(rows) = senCfoBins(:,sceneIndex)- ...
        trueCfoBins(:,sceneIndex);
    trueRate(rows) = trueRateBinsPerSec(:,sceneIndex);
    senRate(rows) = senRateBinsPerSec(:,sceneIndex);
    accepted(rows) = senAccepted(:,sceneIndex);
    cursor = cursor+config.payloadSymbolCount;
end
resultTable = table(scenario,orbitStartSec,payloadSymbol,frameTimeSec, ...
    trueCfo,staticCfo,senCfo,staticResidual,senResidual,trueRate,senRate, ...
    accepted);
writetable(resultTable,fullfile(resultDir, ...
    'stage48_common_bootstrap_validation.csv'));

fig = figure('Visible','off','Color','w','Position',[60 40 1420 830]);
tiledlayout(2,2,'TileSpacing','compact','Padding','compact');
for scene = 1:sceneCount
    ax = nexttile(scene);
    plot(payloadTimeSec,staticCfoBins(:,scene)-trueCfoBins(:,scene), ...
        'r--','LineWidth',1.45,'DisplayName','Huang-PREC-static-CP');
    hold on;
    plot(payloadTimeSec,senCfoBins(:,scene)-trueCfoBins(:,scene), ...
        'b-','LineWidth',1.45,'DisplayName','SenLoRa-VP');
    acceptedRows = find(senAccepted(:,scene));
    if ~isempty(acceptedRows)
        plot(payloadTimeSec(acceptedRows), ...
            senCfoBins(acceptedRows,scene)-trueCfoBins(acceptedRows,scene), ...
            'bo','MarkerSize',4,'MarkerFaceColor','none', ...
            'DisplayName','Accepted virtual pilot');
    end
    yline(0,'k:','HandleVisibility','off');
    grid on; grid minor;
    xlabel('Time within frame (s)');
    ylabel('CFO residual (bin)');
    title(sprintf('%s: static RMSE %.3g, SenLoRa %.3g bin', ...
        scenarioTitles{scene},staticRmseBins(scene),senRmseBins(scene)), ...
        'FontWeight','normal');
    legend('Location','best','FontSize',8,'Box','on');
    set(ax,'FontName','Times New Roman','FontSize',10,'Box','on', ...
        'GridLineStyle',':','MinorGridLineStyle',':');

    ax = nexttile(sceneCount+scene);
    plot(payloadTimeSec,zeros(size(payloadTimeSec)), ...
        'r--','LineWidth',1.45,'DisplayName','Huang-PREC static rate');
    hold on;
    plot(payloadTimeSec,senRateBinsPerSec(:,scene), ...
        'b-','LineWidth',1.45,'DisplayName','SenLoRa estimated rate');
    plot(payloadTimeSec,trueRateBinsPerSec(:,scene), ...
        'k:','LineWidth',1.45,'DisplayName','True rate (audit only)');
    grid on; grid minor;
    xlabel('Time within frame (s)');
    ylabel('Doppler rate (bin/s)');
    title(sprintf('Initial preamble-rate estimate %.6f bin/s; %d pilots', ...
        initialRateBinsPerSec(scene),sum(senAccepted(:,scene))), ...
        'FontWeight','normal');
    legend('Location','best','FontSize',8,'Box','on');
    set(ax,'FontName','Times New Roman','FontSize',10,'Box','on', ...
        'GridLineStyle',':','MinorGridLineStyle',':');
end
sgtitle(sprintf(['Stage 48 mechanism check: shared Huang-PREC CFO, ' ...
    'Sample SNR = %s dB'],localSnrText(options.SampleSnrDb)), ...
    'FontName','Times New Roman','FontWeight','normal');

imagePath = fullfile(resultDir,'stage48_common_bootstrap_validation.png');
exportgraphics(fig,imagePath,'Resolution',180);
savefig(fig,fullfile(resultDir,'stage48_common_bootstrap_validation.fig'));
close(fig);
save(fullfile(resultDir,'stage48_common_bootstrap_validation.mat'), ...
    'config','options','scenarioKeys','startTimes','payloadTimeSec', ...
    'trueCfoBins','trueRateBinsPerSec','staticCfoBins','senCfoBins', ...
    'senRateBinsPerSec','senAccepted','initialCfoBins', ...
    'initialRateBinsPerSec','staticRmseBins','senRmseBins','resultTable');

report = struct('resultDir',resultDir,'imagePath',imagePath, ...
    'table',resultTable,'staticRmseBins',staticRmseBins, ...
    'senRmseBins',senRmseBins,'senAcceptedCount',sum(senAccepted,1).', ...
    'initialCfoBins',initialCfoBins, ...
    'initialRateBinsPerSec',initialRateBinsPerSec);
fprintf('Stage 48 common-bootstrap validation: %s\n',resultDir);
for scene = 1:sceneCount
    fprintf('%s: static RMSE %.6g, SenLoRa RMSE %.6g bin, pilots %d\n', ...
        scenarioKeys{scene},staticRmseBins(scene),senRmseBins(scene), ...
        sum(senAccepted(:,scene)));
end
end

function text = localSnrText(snrDb)
if isinf(snrDb)
    text = 'Inf';
else
    text = sprintf('%.1f',snrDb);
end
end
