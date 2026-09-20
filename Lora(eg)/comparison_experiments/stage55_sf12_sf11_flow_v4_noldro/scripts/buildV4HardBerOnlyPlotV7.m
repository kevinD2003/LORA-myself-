function artifact = buildV4HardBerOnlyPlotV7()
%BUILDV4HARDBERONLYPLOTV7 Plot Hard BER only; ML BER is excluded.
root = v4SetupPaths();
reportPath = fullfile(root,'results','reports', ...
    'B_CASE2_PAPER_FIG11_ALIGNED_V7_REPORT.mat');
loaded = load(reportPath,'report');report = loaded.report;
snrs = report.snrDb(:);
hardBer = squeeze(report.metrics(:,:,:,2));
hardDen = squeeze(report.denominators(:,:,:,2));
plotBer = hardBer;
zero = plotBer == 0;
plotBer(zero) = 0.5./hardDen(zero);

order = [1 3 2];
colors = [.35 .35 .35;0 .447 .741;.85 .325 .098];
styles = {'-.^','--o','-s'};
display = {'Huang','Paper','Stage55'};
figureHandle = figure('Visible','off','Color','w', ...
    'Position',[100 100 1250 500]);
tiles = tiledlayout(figureHandle,1,2, ...
    'TileSpacing','compact','Padding','compact');
for caseIndex = 1:2
    nexttile;
    for k = 1:3
        method = order(k);
        semilogy(snrs,squeeze(plotBer(caseIndex,:,method)),styles{k}, ...
            'Color',colors(k,:),'LineWidth',1.8,'MarkerSize',6, ...
            'DisplayName',display{k});
        hold on
    end
    grid on;grid minor
    xlabel('SNR (dB)');ylabel('Hard BER');
    title(sprintf('Case %d - Hard BER',caseIndex));
    xlim([snrs(1) snrs(end)]);ylim([1e-7 1]);
    legend('Location','southwest');
end
title(tiles,{'Case-anchor AWGN V7: Hard BER only', ...
    'ML BER excluded; zero errors shown at 0.5/N'},'FontWeight','bold');

out = fullfile(root,'results','reports');
pngPath = fullfile(out,'B_CASE2_PAPER_FIG11_ALIGNED_V7_HARD_BER.png');
figPath = fullfile(out,'B_CASE2_PAPER_FIG11_ALIGNED_V7_HARD_BER.fig');
exportgraphics(figureHandle,pngPath,'Resolution',220);
savefig(figureHandle,figPath);close(figureHandle);
artifact = struct('status','PASS', ...
    'identity','B-paper-curve-v7-hard-ber-only', ...
    'metric','hard-BER','mlBerPlotted',false, ...
    'sourceReport',reportPath,'sourceReportSha256',v4Sha256(reportPath), ...
    'snrDb',snrs.','hardBer',hardBer, ...
    'zeroErrorPlotConvention','0.5/N; raw values remain zero', ...
    'pngPath',pngPath,'figPath',figPath, ...
    'stage55Modified',false,'receiverRecomputed',false);
jsonPath = fullfile(out, ...
    'B_CASE2_PAPER_FIG11_ALIGNED_V7_HARD_BER.json');
file = fopen(jsonPath,'w','n','UTF-8');cleaner = onCleanup(@()fclose(file));
fprintf(file,'%s\n',jsonencode(artifact,'PrettyPrint',true));clear cleaner
end
