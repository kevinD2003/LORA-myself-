function summary = run_senlora_confidence_orbit_demo()
%RUNSENLORA CONFIDENCE ORBIT DEMO Exercise SenLoRa mask iteration.
%
% This is a moderate-SNR checkpoint, not the final BER scan.  It confirms
% that the FFT probability, Gray LLR, soft-Hamming and EMA threshold chain
% feeds the virtual-pilot tracker without supplying payload truth.

rootFolder = fileparts(mfilename("fullpath"));
resultFolder = fullfile(rootFolder, "results", "senlora_confidence");
if ~isfolder(resultFolder)
    mkdir(resultFolder);
end

config = senloraChannelConfig();
payloadBins = mod((1:config.payloadSymbolCount).'*73 + 19, ...
    config.spreadingFactorSamples);
symbolBins = [zeros(config.bootstrapPilotCount,1); payloadBins];
scenarioCount = numel(config.scenarios);
snrDb = 0;
summaryRows = repmat(struct(),scenarioCount,1);

fig = figure("Visible","off","Color","w","Position",[60,60,1550,1080]);
layout = tiledlayout(3,scenarioCount,"TileSpacing","compact", ...
    "Padding","compact");

for scenarioIdx = 1:scenarioCount
    scenario = config.scenarios(scenarioIdx);
    [rxSymbols,~,truth] = generateSenLoRaOrbitFrame( ...
        symbolBins,config,StartTimeSec=scenario.startTimeSec, ...
        SampleSnrDb=snrDb,NoiseSeed=config.randomSeedNoise+100+scenarioIdx);
    result = senloraDynamicConfidenceIteration( ...
        rxSymbols,config,zeros(config.bootstrapPilotCount,1));

    symbolTimeSec = truth.symbolStartTimeSec + config.symbolDurationSec/2;
    finalMask = result.finalMask;
    finalMask(1:config.bootstrapPilotCount) = true;

    nexttile(layout,scenarioIdx);
    plot(symbolTimeSec,truth.trueCfoBins,"k-","LineWidth",1.6); hold on;
    plot(symbolTimeSec,result.predictedCfoBins,"r-","LineWidth",1.2);
    accepted = result.pilotUpdateFlag;
    stem(symbolTimeSec(accepted),result.predictedCfoBins(accepted), ...
        "m.","MarkerSize",10);
    xline(symbolTimeSec(config.bootstrapPilotCount),":");
    grid on; box on;
    xlabel("Symbol-center time (s)");
    ylabel("Carrier CFO (bin)");
    title(sprintf("%s, SNR=%g dB",strrep(scenario.name,"_"," "),snrDb));
    if scenarioIdx == 1
        legend("carrier trajectory","final prediction","accepted virtual pilots", ...
            "bootstrap boundary","Location","best");
    end

    nexttile(layout,scenarioIdx+scenarioCount);
    confidence = result.confidence;
    plot(symbolTimeSec,confidence,"b.-","LineWidth",1.0); hold on;
    plot(symbolTimeSec,result.tauGlobal,"r--","LineWidth",1.1);
    stem(symbolTimeSec(finalMask),confidence(finalMask),"g.", ...
        "MarkerSize",10);
    xline(symbolTimeSec(config.bootstrapPilotCount),":");
    grid on; box on;
    xlabel("Symbol-center time (s)");
    ylabel("sum |LLR|^2");
    title(sprintf("SenLoRa confidence, iterations=%d",result.iterations));
    if scenarioIdx == 1
        legend("confidence","EMA threshold","final mask","bootstrap boundary", ...
            "Location","best");
    end

    nexttile(layout,scenarioIdx+2*scenarioCount);
    yyaxis left
    plot(symbolTimeSec,truth.trueDopplerRateHzPerSec,"k-","LineWidth",1.4); hold on;
    plot(symbolTimeSec,result.predictedRateBinsPerSec*config.fftBinSpacingHz, ...
        "r-","LineWidth",1.1);
    ylabel("Doppler rate (Hz/s)");
    yyaxis right
    stairs(symbolTimeSec,result.pilotCount,"m:","LineWidth",1.2);
    ylabel("accepted pilot count");
    xline(symbolTimeSec(config.bootstrapPilotCount),":");
    grid on; box on;
    xlabel("Symbol-center time (s)");
    title("Rate prediction and dynamic pilot history");

    summaryRows(scenarioIdx).name = scenario.name;
    summaryRows(scenarioIdx).sampleSnrDb = snrDb;
    summaryRows(scenarioIdx).iterations = result.iterations;
    summaryRows(scenarioIdx).converged = result.converged;
    summaryRows(scenarioIdx).requestedPayloadPilots = ...
        sum(result.pilotUpdateRequested(config.bootstrapPilotCount+1:end));
    summaryRows(scenarioIdx).acceptedPayloadPilots = ...
        sum(result.pilotUpdateFlag(config.bootstrapPilotCount+1:end));
    summaryRows(scenarioIdx).finalMaskPayloadCount = ...
        sum(finalMask(config.bootstrapPilotCount+1:end));
    summaryRows(scenarioIdx).symbolErrors = ...
        sum(result.detectedBins ~= symbolBins);
    summaryRows(scenarioIdx).payloadSymbolErrors = ...
        sum(result.detectedBins(config.bootstrapPilotCount+1:end) ~= ...
        symbolBins(config.bootstrapPilotCount+1:end));
    summaryRows(scenarioIdx).falseAcceptCount = ...
        sum(result.pilotUpdateFlag & ...
        (result.detectedBins ~= symbolBins));
    summaryRows(scenarioIdx).maxCfoPredictionErrorBins = ...
        max(abs(result.predictedCfoBins(config.bootstrapPilotCount+1:end) - ...
        truth.trueCfoBins(config.bootstrapPilotCount+1:end)));
end

title(layout,"SenLoRa dynamic confidence iteration checkpoint");
exportgraphics(fig,fullfile(resultFolder,"senlora_confidence_demo.png"), ...
    "Resolution",180);
close(fig);

summary = struct( ...
    "folder",resultFolder, ...
    "sampleSnrDb",snrDb, ...
    "symbolBins",symbolBins, ...
    "scenario",summaryRows, ...
    "note","Receiver output is generated without payload truth; truth is used only for this diagnostic.");
fid = fopen(fullfile(resultFolder,"senlora_confidence_metadata.json"),"w");
if fid < 0
    error("SenLoRa:MetadataOpenFailed","Could not write confidence metadata.");
end
cleanup = onCleanup(@()fclose(fid));
fwrite(fid,jsonencode(summary),"char");
end
