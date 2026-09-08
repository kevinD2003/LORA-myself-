function report = run_stage3_layered_diagnostics()
%RUN_STAGE3_LAYERED_DIAGNOSTICS Separate channel, compensation, and pilot errors.
%   This is a compact diagnosis, not the formal BER experiment.  It uses
%   common frames/noise for all receivers and exposes false virtual-pilot
%   admissions using truth only after receiver processing.

root = fileparts(mfilename('fullpath'));
resultDir = fullfile(root,'results','stage3_layered_diagnostics');
if ~isfolder(resultDir)
    mkdir(resultDir);
end
config = satelliteFig3Config();
[window,~] = satelliteFig3VisibilityWindow(config);
startTime = window.deltaTimeInSec;
snrDb = (-24:2:-14).';
frameCount = 3;
payloadCount = config.payloadSymbolCount;
methodNames = {'awgn_only','ideal_phase','hard_rolling8','senlora_rolling8'};
methodCount = numel(methodNames);
symbolErrors = zeros(numel(snrDb),methodCount);
payloadSymbols = zeros(numel(snrDb),1);
acceptedCount = zeros(numel(snrDb),1);
falseAcceptedCount = zeros(numel(snrDb),1);
senIterations = zeros(numel(snrDb),1);

for snrIndex = 1:numel(snrDb)
    for frame = 1:frameCount
        symbolSeed = config.randomSeedSymbols + 1000*snrIndex + frame;
        noiseSeed = config.randomSeedNoise + 1000*snrIndex + frame;
        payload = satelliteFig3GeneratePayload(config,symbolSeed);
        bins = [zeros(config.bootstrapPilotCount,1);payload.symbolBins];
        [rx,tx,truth] = generateContinuousSatelliteFrame(bins,config, ...
            StartTimeSec=startTime,SampleSnrDb=snrDb(snrIndex),NoiseSeed=noiseSeed);
        channelNoise = rx-tx.*exp(1i*truth.phaseRad);
        awgnOnly = tx+channelNoise;
        idealPhase = rx.*exp(-1i*truth.phaseRad);
        hard = satelliteFig3RollingPilotTracker(rx,config, ...
            zeros(config.bootstrapPilotCount,1), ...
            AcceptedMask=true(numel(bins),1),ForceAccept=true);
        senlora = satelliteFig3SenLoRaIterativeDecode(rx,config, ...
            zeros(config.bootstrapPilotCount,1));
        decisions = [localDecode(awgnOnly,config), ...
            localDecode(idealPhase,config), ...
            hard.detectedWaveformBins,senlora.detectedWaveformBins];
        payloadRows = config.bootstrapPilotCount+(1:payloadCount);
        symbolErrors(snrIndex,:) = symbolErrors(snrIndex,:) + ...
            sum(decisions(payloadRows,:) ~= bins(payloadRows),1);
        payloadSymbols(snrIndex) = payloadSymbols(snrIndex)+payloadCount;
        accepted = senlora.pilotAccepted(payloadRows);
        acceptedCount(snrIndex) = acceptedCount(snrIndex)+sum(accepted);
        falseAcceptedCount(snrIndex) = falseAcceptedCount(snrIndex)+sum( ...
            accepted & senlora.detectedWaveformBins(payloadRows) ~= bins(payloadRows));
        senIterations(snrIndex) = senIterations(snrIndex)+senlora.iterations;
    end
end

serRaw = symbolErrors./payloadSymbols;
upper95 = 3./payloadSymbols;
serForLine = serRaw;
upper95Matrix = repmat(upper95,1,methodCount);
zeroMask = symbolErrors == 0;
serForLine(zeroMask) = upper95Matrix(zeroMask);
falseAcceptanceRate = falseAcceptedCount./max(acceptedCount,1);

fig = figure('Visible','off','Color','w','Position',[100 100 1220 740]);
subplot(2,1,1)
semilogy(snrDb,serForLine(:,1),'o-','LineWidth',1.5); hold on
semilogy(snrDb,serForLine(:,2),'s-','LineWidth',1.5);
semilogy(snrDb,serForLine(:,3),'^-','LineWidth',1.5);
semilogy(snrDb,serForLine(:,4),'d-','LineWidth',1.5);
grid on; ylim([1e-3 1]);
xlabel('Sample SNR (dB)'); ylabel('Payload SER');
title('Layered diagnostic: common frame/noise, no curve fitting');
legend('AWGN only','Ideal samplewise phase compensation', ...
    'Hard-decision rolling 8','SenLoRa confidence rolling 8','Location','southwest');
subplot(2,1,2)
yyaxis left
bar(snrDb,acceptedCount/frameCount,0.7); ylabel('Accepted virtual pilots / frame');
yyaxis right
plot(snrDb,falseAcceptanceRate,'o-','LineWidth',1.5); hold on
plot(snrDb,senIterations/frameCount,'s-','LineWidth',1.2);
ylabel('False-admission rate / iterations'); grid on
xlabel('Sample SNR (dB)');
legend('Accepted virtual pilots / frame','False-admission rate','SenLoRa iterations','Location','best');
exportgraphics(fig,fullfile(resultDir,'layered_physics_diagnostic.png'),'Resolution',180);
savefig(fig,fullfile(resultDir,'layered_physics_diagnostic.fig'));
close(fig);

report = struct( ...
    'snrDb',snrDb, 'frameCount',frameCount, 'payloadSymbols',payloadSymbols, ...
    'methodNames',{methodNames}, 'symbolErrors',symbolErrors, ...
    'serRaw',serRaw, 'serForLine',serForLine, 'zeroErrorUpper95',upper95, ...
    'acceptedCount',acceptedCount, 'falseAcceptedCount',falseAcceptedCount, ...
    'falseAcceptanceRate',falseAcceptanceRate, ...
    'meanSenLoRaIterations',senIterations/frameCount, ...
    'scenario','high_doppler_rate', 'startTimeSec',startTime, ...
    'resultDir',resultDir);
save(fullfile(resultDir,'stage3_layered_report.mat'),'report');
writecell([{'snr_db','payload_symbols','awgn_ser','ideal_phase_ser','hard_rolling8_ser','senlora_rolling8_ser','accepted_pilots','false_accepted','mean_iterations'}; ...
    num2cell([snrDb,payloadSymbols,serRaw,acceptedCount,falseAcceptedCount,senIterations/frameCount])], ...
    fullfile(resultDir,'stage3_layered_report.csv'));
fprintf('Stage 3 result folder: %s\\n',resultDir);
end

function bins = localDecode(symbols,config)
bins = zeros(size(symbols,1),1);
for row = 1:size(symbols,1)
    decision = satelliteFig3HardDecision(symbols(row,:),config);
    bins(row) = decision.waveformBin;
end
end
