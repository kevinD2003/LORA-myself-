function report = run_stage26_formal_ber(options)
%RUN_STAGE26_FORMAL_BER Checkpointed two-scenario final BER experiment.
%   Every frame uses common payload/noise for both orbit scenes and all
%   receiver arms.  A point completes after every simulated arm has at
%   least TARGETBITERRORS, or after the common bit count reaches
%   MAXBITSPERPOINT.  No curve fitting, interpolation, or smoothing occurs.

arguments
    options.SnrGridDb (:,1) double = (-30:1:-14).'
    options.TargetBitErrors (1,1) double ...
        {mustBeInteger,mustBePositive} = 300
    options.MaxBitsPerPoint (1,1) double ...
        {mustBeInteger,mustBePositive} = 1e7
    options.StopUpperBerTarget (1,1) double {mustBePositive} = 1e-6
    options.FrameBudgetThisCall (1,1) double ...
        {mustBeInteger,mustBePositive} = 20
    options.SymbolSeedBase (1,1) double = 2026100100
    options.NoiseSeedBase (1,1) double = 2026100200
    options.OutputFolderName (1,:) char = ...
        'stage45_formal_ber_minus30_to_minus14'
    options.Resume (1,1) logical = true
end

root = fileparts(mfilename('fullpath'));
resultDir = fullfile(root,'results',options.OutputFolderName);
if ~isfolder(resultDir), mkdir(resultDir); end
checkpointPath = fullfile(resultDir,'formal_ber_checkpoint.mat');
config = satelliteFig3Config();
[window,~] = satelliteFig3VisibilityWindow(config);
scenarioKeys = {'high_doppler_shift','high_doppler_rate'};
scenarioTitles = {'High Doppler shift','High Doppler rate'};
startTimes = [-window.deltaTimeOutSec,window.deltaTimeInSec];
methodNames = {'Doppler, no compensation', ...
    'Hard-decision PREC rolling-8','SenLoRa rolling-8'};
scenarioCount = numel(scenarioKeys);
snrCount = numel(options.SnrGridDb);
methodCount = numel(methodNames);

signature = localSignature(options,config);
if options.Resume && isfile(checkpointPath)
    loaded = load(checkpointPath,'state','savedSignature');
    if ~isequaln(loaded.savedSignature,signature)
        error('SatelliteFig3:FormalResumeMismatch', ...
            ['The existing checkpoint does not match the requested SNR, ', ...
            'limits, seeds, or physical configuration.']);
    end
    state = loaded.state;
else
    state = localInitialState(scenarioCount,snrCount,methodCount);
end

known = zeros(config.bootstrapPilotCount,1);
framesUsedThisCall = 0;
for snrIndex = 1:snrCount
    if state.terminationReached, break; end
    if state.completed(snrIndex), continue; end
    while ~localPointComplete(state,snrIndex,options) && ...
            framesUsedThisCall < options.FrameBudgetThisCall
        state.frameCount(snrIndex) = state.frameCount(snrIndex)+1;
        frame = state.frameCount(snrIndex);
        symbolSeed = options.SymbolSeedBase+100000*snrIndex+frame;
        noiseSeed = options.NoiseSeedBase+100000*snrIndex+frame;
        payload = satelliteFig3GeneratePayload(config,symbolSeed);
        labels = [known;payload.symbolBins];
        payloadRows = config.bootstrapPilotCount+1:numel(labels);
        noiseReference = [];
        for scenario = 1:scenarioCount
            [rx,tx,truth] = generateContinuousSatelliteFrame(labels,config, ...
                StartTimeSec=startTimes(scenario), ...
                SampleSnrDb=options.SnrGridDb(snrIndex), ...
                NoiseSeed=noiseSeed);
            channelNoise = rx-tx.*exp(1i*truth.phaseRad);
            if scenario == 1
                noiseReference = channelNoise;
            else
                state.commonNoiseMaxDifference = max( ...
                    state.commonNoiseMaxDifference, ...
                    max(abs(channelNoise-noiseReference),[],'all'));
            end

            noCompBins = localHardBins(rx,config);
            decodedNoComp = satelliteFig3HardPayloadBits( ...
                noCompBins(payloadRows),config);
            hard = satelliteFig3HardPrecDecode(rx,config,known);
            sen = satelliteFig3AdaptiveRateReplaySenLoRaDecode( ...
                rx,config,known);
            decoded = {decodedNoComp,hard.decodedDataBits, ...
                sen.hardDecodedDataBits};
            for method = 1:methodCount
                state.errors(scenario,snrIndex,method) = ...
                    state.errors(scenario,snrIndex,method)+sum( ...
                    decoded{method}(:) ~= payload.dataBits(:));
            end

            hardMask = hard.pilotAccepted(payloadRows);
            senMask = sen.pilotAccepted(payloadRows);
            state.hardAccepted(scenario,snrIndex) = ...
                state.hardAccepted(scenario,snrIndex)+sum(hardMask);
            state.hardFalse(scenario,snrIndex) = ...
                state.hardFalse(scenario,snrIndex)+sum(hardMask & ...
                hard.detectedWaveformBins(payloadRows) ~= labels(payloadRows));
            state.senAccepted(scenario,snrIndex) = ...
                state.senAccepted(scenario,snrIndex)+sum(senMask);
            state.senFalse(scenario,snrIndex) = ...
                state.senFalse(scenario,snrIndex)+sum(senMask & ...
                sen.detectedWaveformBins(payloadRows) ~= labels(payloadRows));
            state.senReplayTriggered(scenario,snrIndex) = ...
                state.senReplayTriggered(scenario,snrIndex)+ ...
                sen.rateReplay.triggered;
            state.senRateReleased(scenario,snrIndex) = ...
                state.senRateReleased(scenario,snrIndex)+ ...
                (sen.tracker.acceptedVirtualPilotCount >= ...
                config.senloraRateReleasePilotCount);

            truthBins = truth.trueDopplerHz/config.fftBinSpacingHz;
            hardDelta = hard.tracker.predictedCfoBins(payloadRows)- ...
                truthBins(payloadRows);
            senDelta = sen.tracker.predictedCfoBins(payloadRows)- ...
                truthBins(payloadRows);
            state.hardPredictionSse(scenario,snrIndex) = ...
                state.hardPredictionSse(scenario,snrIndex)+sum(hardDelta.^2);
            state.senPredictionSse(scenario,snrIndex) = ...
                state.senPredictionSse(scenario,snrIndex)+sum(senDelta.^2);
            state.hardPredictionSamples(scenario,snrIndex) = ...
                state.hardPredictionSamples(scenario,snrIndex)+numel(hardDelta);
            state.senPredictionSamples(scenario,snrIndex) = ...
                state.senPredictionSamples(scenario,snrIndex)+numel(senDelta);

            if isempty(state.trace{scenario,snrIndex})
                state.trace{scenario,snrIndex} = localTrace( ...
                    symbolSeed,noiseSeed,truthBins,hard,sen,payloadRows);
            end
        end
        state.bits(snrIndex) = state.bits(snrIndex)+numel(payload.dataBits);
        framesUsedThisCall = framesUsedThisCall+1;
        state.completed(snrIndex) = ...
            localPointComplete(state,snrIndex,options);
        if localUpperBerTargetReached(state,snrIndex,options)
            state.completed(snrIndex) = true;
            state.terminationReached = true;
            state.terminationSnrIndex = snrIndex;
        end
        savedSignature = signature;
        save(checkpointPath,'state','savedSignature','options','config', ...
            'scenarioKeys','startTimes','methodNames','-v7.3');
    end
    if framesUsedThisCall >= options.FrameBudgetThisCall, break; end
end

[resultTable,imagePath] = localWriteResults(resultDir,state,options, ...
    config,scenarioKeys,scenarioTitles,methodNames);
seedTable = localWriteSeedPolicy(resultDir,state,options);
report = struct('resultDir',resultDir,'checkpointPath',checkpointPath, ...
    'imagePath',imagePath,'table',resultTable,'seedTable',seedTable, ...
    'state',state,'framesUsedThisCall',framesUsedThisCall, ...
    'allCompleted',state.terminationReached || all(state.completed));
fprintf('Stage 26 formal BER checkpoint: %s\n',resultDir);
fprintf('This call processed %d frames; %d/%d SNR points complete.\n', ...
    framesUsedThisCall,sum(state.completed),snrCount);
end

function signature = localSignature(options,config)
signature = struct('snrGridDb',options.SnrGridDb, ...
    'targetBitErrors',options.TargetBitErrors, ...
    'maxBitsPerPoint',options.MaxBitsPerPoint, ...
    'stopUpperBerTarget',options.StopUpperBerTarget, ...
    'symbolSeedBase',options.SymbolSeedBase, ...
    'noiseSeedBase',options.NoiseSeedBase, ...
    'payloadBerMetric','common_hard_hamming_from_final_compensated_bins', ...
    'sf',config.sf,'bandwidthHz',config.bandwidthHz, ...
    'carrierFrequencyHz',config.carrierFrequencyHz, ...
    'orbitHeightM',config.orbitHeightM, ...
    'inclinationRad',config.inclinationRad, ...
    'bootstrapPilotCount',config.bootstrapPilotCount, ...
    'payloadSymbolCount',config.payloadSymbolCount);
signature.virtualPilotHistoryLength = config.virtualPilotHistoryLength;
signature.maxSenLoRaIterations = config.maxSenLoRaIterations;
signature.confidenceAlpha = config.confidenceAlpha;
signature.confidenceThresholdScale = config.confidenceThresholdScale;
signature.amendLlrMix = config.amendLlrMix;
signature.senloraMinimumMarginRatio = config.senloraMinimumMarginRatio;
signature.senloraRequireSoftHardAgreement = ...
    config.senloraRequireSoftHardAgreement;
signature.confidenceInnovationLimitBins = ...
    config.confidenceInnovationLimitBins;
signature.residualPeakRatioThreshold = ...
    config.residualPeakRatioThreshold;
signature.decisionPeakRatioThreshold = ...
    config.decisionPeakRatioThreshold;
signature.historyDecay = config.historyDecay;
signature.huberThresholdBins = config.huberThresholdBins;
signature.rateReplayPriorHalfWidthBinsPerSec = ...
    config.rateReplayPriorHalfWidthBinsPerSec;
signature.rateReplayPriorStepBinsPerSec = ...
    config.rateReplayPriorStepBinsPerSec;
signature.senloraUseSoftDecodedPilotLabels = ...
    config.senloraUseSoftDecodedPilotLabels;
signature.senloraUseCausalConfidenceTiming = ...
    config.senloraUseCausalConfidenceTiming;
signature.senloraRateReleasePilotCount = ...
    config.senloraRateReleasePilotCount;
signature.senloraRateTrackingDeviationLimitBinsPerSec = ...
    config.senloraRateTrackingDeviationLimitBinsPerSec;
signature.hardPrecRateReleasePilotCount = ...
    config.hardPrecRateReleasePilotCount;
signature.hardPrecRateTrackingDeviationLimitBinsPerSec = ...
    config.hardPrecRateTrackingDeviationLimitBinsPerSec;
end

function state = localInitialState(sceneCount,snrCount,methodCount)
state = struct( ...
    'errors',zeros(sceneCount,snrCount,methodCount), ...
    'bits',zeros(snrCount,1), ...
    'frameCount',zeros(snrCount,1), ...
    'completed',false(snrCount,1), ...
    'hardAccepted',zeros(sceneCount,snrCount), ...
    'hardFalse',zeros(sceneCount,snrCount), ...
    'senAccepted',zeros(sceneCount,snrCount), ...
    'senFalse',zeros(sceneCount,snrCount), ...
    'senReplayTriggered',zeros(sceneCount,snrCount), ...
    'senRateReleased',zeros(sceneCount,snrCount), ...
    'hardPredictionSse',zeros(sceneCount,snrCount), ...
    'senPredictionSse',zeros(sceneCount,snrCount), ...
    'hardPredictionSamples',zeros(sceneCount,snrCount), ...
    'senPredictionSamples',zeros(sceneCount,snrCount), ...
    'commonNoiseMaxDifference',0, ...
    'terminationReached',false, ...
    'terminationSnrIndex',NaN, ...
    'trace',{cell(sceneCount,snrCount)});
end

function complete = localPointComplete(state,snrIndex,options)
if state.bits(snrIndex) >= options.MaxBitsPerPoint
    complete = true;
    return
end
pointErrors = reshape(state.errors(:,snrIndex,:),[],1);
complete = ~isempty(pointErrors) && ...
    all(pointErrors >= options.TargetBitErrors);
end

function reached = localUpperBerTargetReached(state,snrIndex,options)
if state.bits(snrIndex) <= 0
    reached = false;
    return
end
errors = reshape(state.errors(:,snrIndex,2:3),[],1);
bits = repmat(state.bits(snrIndex),numel(errors),1);
[~,~,upper] = satelliteFig3BerInterval95(errors,bits);
reached = all(upper <= options.StopUpperBerTarget);
end

function trace = localTrace(symbolSeed,noiseSeed,truthBins,hard,sen,rows)
trace = struct('symbolSeed',symbolSeed,'noiseSeed',noiseSeed, ...
    'payloadRows',rows(:), ...
    'truthCfoBins',truthBins(rows), ...
    'hardPredictedCfoBins',hard.tracker.predictedCfoBins(rows), ...
    'hardPredictedRateBinsPerSec', ...
        hard.tracker.predictedRateBinsPerSec(rows), ...
    'hardResidualBins',hard.tracker.measuredResidualBins(rows), ...
    'hardPilotAccepted',hard.pilotAccepted(rows), ...
    'senPredictedCfoBins',sen.tracker.predictedCfoBins(rows), ...
    'senPredictedRateBinsPerSec', ...
        sen.tracker.predictedRateBinsPerSec(rows), ...
    'senResidualBins',sen.tracker.measuredResidualBins(rows), ...
    'senPilotAccepted',sen.pilotAccepted(rows), ...
    'senRateReplay',sen.rateReplay);
end

function [resultTable,imagePath] = localWriteResults( ...
        resultDir,state,options,config,scenarioKeys,scenarioTitles,methodNames)
sceneCount = numel(scenarioKeys);
snrCount = numel(options.SnrGridDb);
methodCount = numel(methodNames);
bitMatrix = repmat(reshape(state.bits,1,snrCount,1), ...
    sceneCount,1,methodCount);
valid = bitMatrix > 0;
shown = nan(size(state.errors)); lower = nan(size(state.errors));
upper = nan(size(state.errors)); raw = nan(size(state.errors));
if any(valid,'all')
    [shown(valid),lower(valid),upper(valid)] = ...
        satelliteFig3BerInterval95(state.errors(valid),bitMatrix(valid));
    raw(valid) = state.errors(valid)./bitMatrix(valid);
end
[theory,uncodedTheory] = satelliteFig3TheoreticalHammingBerAwgn( ...
    config.sf,options.SnrGridDb);

rowCount = sceneCount*snrCount;
scenario = cell(rowCount,1); snrDb = zeros(rowCount,1);
bits = zeros(rowCount,1); frames = zeros(rowCount,1);
completed = false(rowCount,1); theoryBer = zeros(rowCount,1);
completionReason = cell(rowCount,1);
uncodedBer = zeros(rowCount,1);
err = zeros(rowCount,methodCount); ber = nan(rowCount,methodCount);
lo = nan(rowCount,methodCount); hi = nan(rowCount,methodCount);
hardAccepted = zeros(rowCount,1); hardFalse = zeros(rowCount,1);
senAccepted = zeros(rowCount,1); senFalse = zeros(rowCount,1);
replayCount = zeros(rowCount,1); hardRmse = nan(rowCount,1);
releaseCount = zeros(rowCount,1);
senRmse = nan(rowCount,1);
row = 0;
for scene = 1:sceneCount
    for s = 1:snrCount
        row = row+1; scenario{row}=scenarioKeys{scene};
        snrDb(row)=options.SnrGridDb(s); bits(row)=state.bits(s);
        frames(row)=state.frameCount(s); completed(row)=state.completed(s);
        if state.terminationReached && s == state.terminationSnrIndex
            completionReason{row} = 'upper_95_at_or_below_target';
        elseif state.completed(s)
            completionReason{row} = 'error_or_bit_target';
        elseif state.terminationReached && s > state.terminationSnrIndex
            completionReason{row} = 'not_simulated_after_upper_target';
        else
            completionReason{row} = 'incomplete';
        end
        theoryBer(row)=theory(s); uncodedBer(row)=uncodedTheory(s);
        err(row,:)=reshape(state.errors(scene,s,:),1,[]);
        ber(row,:)=reshape(shown(scene,s,:),1,[]);
        lo(row,:)=reshape(lower(scene,s,:),1,[]);
        hi(row,:)=reshape(upper(scene,s,:),1,[]);
        hardAccepted(row)=state.hardAccepted(scene,s);
        hardFalse(row)=state.hardFalse(scene,s);
        senAccepted(row)=state.senAccepted(scene,s);
        senFalse(row)=state.senFalse(scene,s);
        replayCount(row)=state.senReplayTriggered(scene,s);
        releaseCount(row)=state.senRateReleased(scene,s);
        if state.hardPredictionSamples(scene,s)>0
            hardRmse(row)=sqrt(state.hardPredictionSse(scene,s)/ ...
                state.hardPredictionSamples(scene,s));
            senRmse(row)=sqrt(state.senPredictionSse(scene,s)/ ...
                state.senPredictionSamples(scene,s));
        end
    end
end
resultTable = table(scenario,snrDb,bits,frames,completed,completionReason,theoryBer, ...
    uncodedBer,err(:,1),err(:,2),err(:,3),ber(:,1),ber(:,2),ber(:,3), ...
    lo(:,1),lo(:,2),lo(:,3),hi(:,1),hi(:,2),hi(:,3), ...
    hardAccepted,hardFalse,senAccepted,senFalse,replayCount, ...
    releaseCount,hardRmse,senRmse,'VariableNames',{ ...
    'scenario','snrDb','bits','frames','completed','completionReason', ...
    'berTheoryHamming', ...
    'berTheoryUncodedAudit','errNoComp','errHardPrec','errSenLoRa', ...
    'berNoComp','berHardPrec','berSenLoRa', ...
    'lower95NoComp','lower95HardPrec','lower95SenLoRa', ...
    'upper95NoComp','upper95HardPrec','upper95SenLoRa', ...
    'hardAccepted','hardFalseAccepted','senAccepted','senFalseAccepted', ...
    'senRateReplayTriggeredFrames','senRateReleasedFrames', ...
    'hardCfoRmseBins','senCfoRmseBins'});
writetable(resultTable,fullfile(resultDir,'formal_ber.csv'));

fig = figure('Visible','off','Color','w','Position',[60 60 1500 660]);
tiledlayout(1,2,'TileSpacing','compact','Padding','compact');
styles={'s-.','x--','o-'};
colors=[0.90 0.00 0.90; 0.20 0.65 0.90; 1.00 0.15 0.05];
mainAxes = gobjects(sceneCount,1);
for scene = 1:sceneCount
    mainAxes(scene) = nexttile;
    semilogy(options.SnrGridDb,max(theory,realmin),'k--', ...
        'LineWidth',1.7,'DisplayName','Theoretical AWGN, Hamming(7,4)');
    hold on;
    for method = 1:methodCount
        y=reshape(shown(scene,:,method),[],1);
        low=reshape(lower(scene,:,method),[],1);
        high=reshape(upper(scene,:,method),[],1);
        finite=isfinite(y);
        errorbar(options.SnrGridDb(finite),y(finite), ...
            y(finite)-max(low(finite),1e-6),high(finite)-y(finite), ...
            styles{method},'Color',colors(method,:),'LineWidth',1.25, ...
            'MarkerSize',5.5,'MarkerFaceColor','none','CapSize',3, ...
            'DisplayName',methodNames{method});
    end
    grid on; grid minor; ylim([1e-6 1]);
    if numel(options.SnrGridDb) == 1
        xlim(options.SnrGridDb+[-0.5;0.5]);
    else
        xlim([min(options.SnrGridDb),max(options.SnrGridDb)]);
    end
    xlabel('Sample SNR (dB)','FontWeight','bold');
    ylabel('Decoded payload BER','FontWeight','bold');
    title(scenarioTitles{scene},'FontWeight','normal');
    legend('Location','southwest','FontSize',8,'Box','on');
    set(mainAxes(scene),'FontName','Times New Roman','FontSize',11, ...
        'LineWidth',0.8,'GridLineStyle',':','MinorGridLineStyle',':', ...
        'GridAlpha',0.35,'MinorGridAlpha',0.22,'Box','on');
end
sgtitle(sprintf(['Formal raw Monte Carlo: %d errors / %.0g bits / ', ...
    '95%% upper <= %.0e'],options.TargetBitErrors,options.MaxBitsPerPoint, ...
    options.StopUpperBerTarget),'FontName','Times New Roman', ...
    'FontWeight','normal');
drawnow;
for scene = 1:sceneCount
    localAddPaperInset(fig,mainAxes(scene),scene,options.SnrGridDb, ...
        theory,shown,styles,colors);
end
for scene = 1:sceneCount
    legend(mainAxes(scene),'Location','southwest','FontSize',8,'Box','on');
end
imagePath=fullfile(resultDir,'formal_ber.png');
exportgraphics(fig,imagePath,'Resolution',180);
savefig(fig,fullfile(resultDir,'formal_ber.fig')); close(fig);
save(fullfile(resultDir,'formal_ber_latest.mat'), ...
    'state','options','config','scenarioKeys','methodNames','resultTable', ...
    'theory','uncodedTheory','raw','shown','lower','upper','-v7.3');
end

function localAddPaperInset(fig,mainAx,scene,snrDb,theory,shown,styles,colors)
% Add a linear, paper-style close-up around the simulated 10^-4 region.
[~,focusIndex] = min(abs(snrDb+20));
focusValues = [theory(focusIndex),shown(scene,focusIndex,2), ...
    shown(scene,focusIndex,3)];
focusValues = focusValues(isfinite(focusValues) & focusValues > 0);
if isempty(focusValues), return; end
span = max(focusValues)-min(focusValues);
padding = max(0.35*span,0.08*max(focusValues));
yLimits = [max(1e-6,min(focusValues)-padding),max(focusValues)+padding];
xCentre = snrDb(focusIndex);
xLimits = xCentre+[-0.28 0];

mainPosition = mainAx.Position;
insetPosition = [mainPosition(1)+0.61*mainPosition(3), ...
    mainPosition(2)+0.64*mainPosition(4), ...
    0.32*mainPosition(3),0.27*mainPosition(4)];
insetAx = axes(fig,'Position',insetPosition,'Color','w'); %#ok<LAXES>
plot(insetAx,snrDb,theory,'k--','LineWidth',1.5);
hold(insetAx,'on');
for method = 1:size(shown,3)
    y = reshape(shown(scene,:,method),[],1);
    finite = isfinite(y);
    plot(insetAx,snrDb(finite),y(finite),styles{method}, ...
        'Color',colors(method,:),'LineWidth',1.15,'MarkerSize',5, ...
        'MarkerFaceColor','none');
end
xlim(insetAx,xLimits); ylim(insetAx,yLimits);
grid(insetAx,'on'); box(insetAx,'on');
set(insetAx,'FontName','Times New Roman','FontSize',8,'LineWidth',0.75, ...
    'GridLineStyle',':','GridAlpha',0.3,'XTick',xCentre);
insetAx.YAxis.Exponent = -4;

rectangle(mainAx,'Position',[xLimits(1),yLimits(1),diff(xLimits),diff(yLimits)], ...
    'EdgeColor',[0.25 0.25 0.25],'LineWidth',0.8);
source = localAxesDataToFigure(mainAx,xLimits(2),yLimits(2));
target = [insetPosition(1)+0.13*insetPosition(3),insetPosition(2)];
annotation(fig,'arrow',[source(1),target(1)],[source(2),target(2)], ...
    'Color','k','LineWidth',0.8,'HeadLength',6,'HeadWidth',6);
end

function position = localAxesDataToFigure(ax,xValue,yValue)
axPosition = ax.Position;
xLimits = ax.XLim;
yLimits = log10(ax.YLim);
position = [axPosition(1)+(xValue-xLimits(1))/diff(xLimits)*axPosition(3), ...
    axPosition(2)+(log10(yValue)-yLimits(1))/diff(yLimits)*axPosition(4)];
end

function seedTable = localWriteSeedPolicy(resultDir,state,options)
snrDb = options.SnrGridDb;
snrIndex = (1:numel(snrDb)).';
framesProcessed = state.frameCount;
firstSymbolSeed = options.SymbolSeedBase+100000*snrIndex+1;
lastSymbolSeed = options.SymbolSeedBase+100000*snrIndex+framesProcessed;
firstNoiseSeed = options.NoiseSeedBase+100000*snrIndex+1;
lastNoiseSeed = options.NoiseSeedBase+100000*snrIndex+framesProcessed;
seedFormula = repmat({ ...
    'base + 100000*snrIndex + frameIndex'},numel(snrDb),1);
seedTable = table(snrIndex,snrDb,framesProcessed,firstSymbolSeed, ...
    lastSymbolSeed,firstNoiseSeed,lastNoiseSeed,seedFormula);
writetable(seedTable,fullfile(resultDir,'random_seed_ledger.csv'));
end

function bins = localHardBins(symbols,config)
bins = zeros(size(symbols,1),1);
for symbol = 1:size(symbols,1)
    decision = satelliteFig3HardDecision(symbols(symbol,:),config);
    bins(symbol) = decision.waveformBin;
end
end
