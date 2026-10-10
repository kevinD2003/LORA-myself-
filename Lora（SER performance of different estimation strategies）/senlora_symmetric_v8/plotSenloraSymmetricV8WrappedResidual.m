function output = plotSenloraSymmetricV8WrappedResidual()
%PLOTSENLORASYMMETRICV8WRAPPEDRESIDUAL Instantaneous CFO and wrapped phase.

projectRoot = fileparts(fileparts(mfilename('fullpath')));
root = fullfile(projectRoot,'results','senlora_symmetric_v8', ...
    'five_point_1000');
sourcePath = fullfile(root,'FIVE_POINT_FIRST_ERROR_CFO_RESIDUAL_TRACE.csv');
if ~isfile(sourcePath)
    error('EXP5V8:WrappedResidualInput','Residual trace is missing.');
end
trace = readtable(sourcePath);
expectedTimes = [-366;-274.5;-183;-91.5;0];
if height(trace)~=5*112 || ...
        ~isequal(unique(trace.orbitStartSec),expectedTimes) || ...
        any(~isfinite(trace.cfoResidualBins))
    error('EXP5V8:WrappedResidualInput','Residual trace is incomplete.');
end

trace.wrappedCumulativePhaseCycles = angle(exp(1i*2*pi* ...
    trace.cumulativeSignedResidualBinSymbols))/(2*pi);
if any(trace.wrappedCumulativePhaseCycles < -0.5-1e-12 | ...
        trace.wrappedCumulativePhaseCycles > 0.5+1e-12)
    error('EXP5V8:WrappedResidualRange','Wrapped phase is outside range.');
end
tablePath = fullfile(root, ...
    'FIVE_POINT_FIRST_ERROR_INSTANTANEOUS_WRAPPED_PHASE.csv');
writetable(trace,tablePath);

packetIds = zeros(5,1);
for point = 1:5
    rows = trace.orbitStartSec==expectedTimes(point);
    ids = unique(trace.packetId(rows));
    if sum(rows)~=112 || numel(ids)~=1 || ...
            sum(trace.symbolError(rows))~=1
        error('EXP5V8:WrappedResidualPacket', ...
            'Expected one complete one-error packet per point.');
    end
    packetIds(point) = ids;
end

figurePath = fullfile(root, ...
    'FIVE_POINT_FIRST_ERROR_INSTANTANEOUS_WRAPPED_PHASE.png');
f = figure('Visible','off','Color','w','Position',[100 100 1120 820]);
tiledlayout(2,1,'TileSpacing','compact','Padding','compact');
colors = lines(5);
labels = compose('%.1f s, packet %d',expectedTimes,packetIds);
nexttile
hold on
for point = 1:5
    rows = trace.orbitStartSec==expectedTimes(point);
    plot(trace.payloadSymbolIndex(rows),trace.cfoResidualBins(rows), ...
        'Color',colors(point,:),'LineWidth',1.35, ...
        'DisplayName',labels{point});
    errors = rows & trace.symbolError;
    scatter(trace.payloadSymbolIndex(errors),trace.cfoResidualBins(errors), ...
        55,colors(point,:),'filled','MarkerEdgeColor','k', ...
        'HandleVisibility','off');
end
yline(0,':','HandleVisibility','off');
grid on;xlim([1 112]);
xlabel('Payload symbol index');
ylabel('Instantaneous CFO residual (bins)');
title('First error packet: estimated CFO minus offline true CFO');
legend('Location','best');
nexttile
hold on
for point = 1:5
    rows = trace.orbitStartSec==expectedTimes(point);
    plot(trace.payloadSymbolIndex(rows), ...
        trace.wrappedCumulativePhaseCycles(rows), ...
        'Color',colors(point,:),'LineWidth',1.35, ...
        'DisplayName',labels{point});
    errors = rows & trace.symbolError;
    scatter(trace.payloadSymbolIndex(errors), ...
        trace.wrappedCumulativePhaseCycles(errors),55, ...
        colors(point,:),'filled','MarkerEdgeColor','k', ...
        'HandleVisibility','off');
end
yline(0,':','HandleVisibility','off');
grid on;xlim([1 112]);ylim([-0.5 0.5]);
xlabel('Payload symbol index');
ylabel('Wrapped cumulative phase error (cycles)');
title('Cumulative phase folded to [-0.5, 0.5] cycles');
legend('Location','best');
exportgraphics(f,figurePath,'Resolution',220);
close(f);

output = struct('tablePath',tablePath,'figurePath',figurePath, ...
    'minimumWrappedPhase',min(trace.wrappedCumulativePhaseCycles), ...
    'maximumWrappedPhase',max(trace.wrappedCumulativePhaseCycles));
end
