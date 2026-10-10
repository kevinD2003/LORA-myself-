function outputPath = plotSenloraSymmetricV8ResidualBySymbol()
%PLOTSENLORASYMMETRICV8RESIDUALBYSYMBOL Small multiples by orbit point.

projectRoot = fileparts(fileparts(mfilename('fullpath')));
root = fullfile(projectRoot,'results','senlora_symmetric_v8', ...
    'five_point_1000');
sourcePath = fullfile(root, ...
    'FIVE_POINT_FIRST_ERROR_INSTANTANEOUS_WRAPPED_PHASE.csv');
if ~isfile(sourcePath)
    error('EXP5V8:ResidualSequenceInput','Residual trace is missing.');
end
trace = readtable(sourcePath);
expectedTimes = [-366;-274.5;-183;-91.5;0];
if height(trace)~=5*112 || ...
        ~isequal(unique(trace.orbitStartSec),expectedTimes)
    error('EXP5V8:ResidualSequenceInput','Residual trace is incomplete.');
end

yLimit = 1.08*max(abs(trace.cfoResidualBins));
blockBoundaries = 7.5:7:105.5;
f = figure('Visible','off','Color','w','Position',[100 80 1120 1160]);
layout = tiledlayout(5,1,'TileSpacing','compact','Padding','compact');
for point = 1:5
    rows = trace.orbitStartSec==expectedTimes(point);
    pointTrace = trace(rows,:);
    errorRow = pointTrace(logical(pointTrace.symbolError),:);
    if height(pointTrace)~=112 || height(errorRow)~=1
        error('EXP5V8:ResidualSequencePacket', ...
            'Expected one complete one-error packet per point.');
    end
    nexttile
    hold on
    for boundary = blockBoundaries
        xline(boundary,':','Color',[0.82 0.82 0.82], ...
            'HandleVisibility','off');
    end
    plot(pointTrace.payloadSymbolIndex,pointTrace.cfoResidualBins, ...
        'Color',[0 0.4470 0.7410],'LineWidth',1.45);
    yline(0,'-','Color',[0.35 0.35 0.35], ...
        'HandleVisibility','off');
    xline(errorRow.payloadSymbolIndex,'--','Color',[0.8 0.15 0.15], ...
        'LineWidth',1.1,'HandleVisibility','off');
    scatter(errorRow.payloadSymbolIndex,errorRow.cfoResidualBins,60, ...
        [0.8 0.15 0.15],'filled','MarkerEdgeColor','k');
    grid on
    xlim([1 112]);
    ylim([-yLimit yLimit]);
    xticks([1 16 32 48 64 80 96 112]);
    title(sprintf(['t = %.1f s, packet %d, error symbol %d, ' ...
        'CFO RMSE = %.4f bin'],expectedTimes(point), ...
        errorRow.packetId,errorRow.payloadSymbolIndex, ...
        sqrt(mean(pointTrace.cfoResidualBins.^2))));
    if point<5
        set(gca,'XTickLabel',[]);
    end
end
xlabel(layout,'Payload symbol index');
ylabel(layout,'Instantaneous CFO residual (bins)');
title(layout,{'CFO residual over the payload symbol sequence', ...
    'Dotted lines mark 7-symbol Hamming block boundaries; red marks the error'});
outputPath = fullfile(root,'FIVE_POINT_FIRST_ERROR_RESIDUAL_BY_SYMBOL.png');
exportgraphics(f,outputPath,'Resolution',220);
close(f);
end
