function output = buildSenloraSymmetricV8ResidualCurves()
%BUILDSENLORASYMMETRICV8RESIDUALCURVES Replay packet 1 at five points.

here = fileparts(mfilename('fullpath'));
addpath(fullfile(here,'..','scripts'));
paths = exp1SetupPaths();
addpath(here);
config = exp1Config();
c = config.parent;
plan = senloraSymmetricV8Config(config);
parameters = v4LoadMethodAlignedR3ParametersV1();
root = fullfile(paths.resultsRoot,'senlora_symmetric_v8','five_point_1000');
summary = readtable(fullfile(root,'FIVE_POINT_1000_SUMMARY.csv'));
packets = readtable(fullfile(root,'FIVE_POINT_1000_RAW_PACKETS.csv'));
expectedTimes = [-366;-274.5;-183;-91.5;0];
if height(summary)~=5 || any(summary.orbitStartSec~=expectedTimes) || ...
        any(summary.packets~=1000) || height(packets)~=5000
    error('EXP5V8:ResidualInput','Five-point source data are incomplete.');
end

counts = summary(:,{'orbitStartSec','packets','senloraRawErrors', ...
    'idealRawErrors','senloraSer','idealSer','exactTheorySer'});
countsPath = fullfile(root,'FIVE_POINT_1000_ERROR_COUNTS.csv');
writetable(counts,countsPath);

n = c.payloadSymbolCount;
traceRows = cell(5*n,9);
packetRows = cell(5,7);
for point = 1:5
    saved = packets(packets.pointIndex==point & packets.packetId==1,:);
    if height(saved)~=1 || saved.orbitStartSec~=expectedTimes(point) || ...
            saved.senloraFailed || saved.idealFailed
        error('EXP5V8:ResidualPacket','Packet 1 is missing or failed.');
    end
    seeds = struct('payloadSeed',saved.payloadSeed, ...
        'noiseSeed',saved.noiseSeed,'channelSeed',0);
    frame = senloraSymmetricV8GenerateFrame( ...
        config,expectedTimes(point),plan.snrDb,seeds);
    pilots = frame.observation.rxPhysical( ...
        frame.observation.layout.bootstrapRows,:);
    common = v4CommonBootstrap(pilots,c, ...
        SearchStepBins=parameters.searchStepBins);
    result = senloraSymmetricV8Decode( ...
        frame.observation,common,config,plan);
    errors = sum(result.detectedPhysicalBins(:)~= ...
        frame.truth.payloadPhysicalBins(:));
    residual = result.estimatedCfoBins(:)-frame.truth.dataCfoBins(:);
    rmse = sqrt(mean(residual.^2));
    if errors~=saved.senloraRawErrors || ...
            abs(rmse-saved.cfoRmseBins)>1e-9 || ...
            abs(result.rateGain-saved.rateGain)>1e-9 || ...
            any(~isfinite(residual))
        error('EXP5V8:ResidualReplay', ...
            'Replay does not match saved packet metrics at %.1f s.', ...
            expectedTimes(point));
    end
    cumulativeSigned = cumsum(residual);
    cumulativeAbsolute = cumsum(abs(residual));
    packetRows(point,:) = {expectedTimes(point),1, ...
        saved.senloraRawErrors,saved.idealRawErrors, ...
        rmse,cumulativeSigned(end),cumulativeAbsolute(end)};
    for symbol = 1:n
        traceRows((point-1)*n+symbol,:) = { ...
            expectedTimes(point),1,symbol, ...
            result.estimatedCfoBins(symbol), ...
            frame.truth.dataCfoBins(symbol),residual(symbol), ...
            cumulativeSigned(symbol),cumulativeAbsolute(symbol), ...
            result.rateGain};
    end
end

trace = cell2table(traceRows,'VariableNames',{ ...
    'orbitStartSec','packetId','payloadSymbolIndex', ...
    'estimatedCfoBins','offlineTrueCfoBins','cfoResidualBins', ...
    'cumulativeSignedResidualBinSymbols', ...
    'cumulativeAbsoluteResidualBinSymbols','rateGain'});
packetSummary = cell2table(packetRows,'VariableNames',{ ...
    'orbitStartSec','packetId','senloraRawErrors','idealRawErrors', ...
    'cfoResidualRmseBins','finalSignedResidualBinSymbols', ...
    'finalAbsoluteResidualBinSymbols'});
tracePath = fullfile(root,'FIVE_POINT_PACKET1_CFO_RESIDUAL_TRACE.csv');
packetPath = fullfile(root,'FIVE_POINT_PACKET1_RESIDUAL_SUMMARY.csv');
writetable(trace,tracePath);
writetable(packetSummary,packetPath);

figurePath = fullfile(root,'FIVE_POINT_PACKET1_CFO_RESIDUAL.png');
f = figure('Visible','off','Color','w','Position',[100 100 1120 820]);
tiledlayout(2,1,'TileSpacing','compact','Padding','compact');
colors = lines(5);
labels = compose('%.1f s',expectedTimes);
nexttile
hold on
for point = 1:5
    rows = trace.orbitStartSec==expectedTimes(point);
    plot(trace.payloadSymbolIndex(rows), ...
        trace.cumulativeSignedResidualBinSymbols(rows), ...
        'Color',colors(point,:),'LineWidth',1.4, ...
        'DisplayName',labels{point});
end
yline(0,':','HandleVisibility','off');
grid on
xlim([1 n]);
xlabel('Payload symbol index');
ylabel('Cumulative signed CFO residual (bin·symbols)');
title('Packet 1 at each orbit point: sum of estimated minus true CFO');
legend('Location','best');
nexttile
hold on
for point = 1:5
    rows = trace.orbitStartSec==expectedTimes(point);
    plot(trace.payloadSymbolIndex(rows), ...
        trace.cumulativeAbsoluteResidualBinSymbols(rows), ...
        'Color',colors(point,:),'LineWidth',1.4, ...
        'DisplayName',labels{point});
end
grid on
xlim([1 n]);
xlabel('Payload symbol index');
ylabel('Cumulative absolute CFO residual (bin·symbols)');
title('Packet 1 at each orbit point: sum of absolute CFO residual');
legend('Location','northwest');
exportgraphics(f,figurePath,'Resolution',220);
close(f);

output = struct('counts',counts,'packetSummary',packetSummary, ...
    'countsPath',countsPath,'tracePath',tracePath, ...
    'packetPath',packetPath,'figurePath',figurePath);
end
