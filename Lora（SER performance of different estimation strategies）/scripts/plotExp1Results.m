function files = plotExp1Results(outputPhase)
%PLOTEXP1RESULTS Required orbit, physics, delta, and within-frame plots.

if nargin < 1
    outputPhase = 'formal';
end
paths = exp1SetupPaths();
summaryRoot = fullfile(paths.resultsRoot,char(outputPhase),'summary');
summary = readtable(fullfile(summaryRoot,'EXP1_ORBIT_POSITION_SUMMARY.csv'));
deltaPath = fullfile(summaryRoot,'EXP1_PAIRED_DELTA_SER.csv');
symbol = readtable(fullfile(summaryRoot,'EXP1_SYMBOL_POSITION_SUMMARY.csv'));
out = fullfile(paths.figuresRoot,char(outputPhase));
if ~isfolder(out)
    mkdir(out);
end
files = strings(0,1);
snrs = unique(summary.snrDb,'stable');
methods = unique(summary.method,'stable');

figureHandle = figure('Visible','off','Color','w','Position',[100 100 1100 450]);
tiles = tiledlayout(figureHandle,1,numel(snrs),'TileSpacing','compact');
for snrIndex = 1:numel(snrs)
    nexttile;
    for method = 1:numel(methods)
        rows = summary.snrDb == snrs(snrIndex) & ...
            strcmp(summary.method,methods{method});
        data = sortrows(summary(rows,:),{'orbitStartSec'});
        if isempty(data)
            continue
        end
        value = max(data.ser,0.5./data.symbolCount);
        lower = max(value-data.serCiLow,0);
        upper = max(data.serCiHigh-value,0);
        errorbar(data.orbitStartSec,value,lower,upper,'-o', ...
            'LineWidth',1.4,'DisplayName',methods{method});
        hold on
    end
    set(gca,'YScale','log');grid on;xlabel('Orbit start t_0 (s)');
    ylabel('Data-symbol SER');title(sprintf('SNR = %.2f dB',snrs(snrIndex)));
    legend('Location','best');
end
title(tiles,sprintf('%s: SER vs orbit position',outputPhase));
path = fullfile(out,'EXP1_A_SER_VS_ORBIT.png');
exportgraphics(figureHandle,path,'Resolution',220);close(figureHandle);files(end+1)=path;

physics = unique(summary(:,{'orbitStartSec','fDStartHz', ...
    'dopplerRateStartHzPerSec','peakAbsDopplerRateHzPerSec', ...
    'frameDriftBins','frameRangeBins'}),'rows');
physics = sortrows(physics,'orbitStartSec');
figureHandle = figure('Visible','off','Color','w','Position',[100 100 900 650]);
tiles = tiledlayout(figureHandle,3,1,'TileSpacing','compact');
nexttile;plot(physics.orbitStartSec,physics.fDStartHz/1e3,'-o','LineWidth',1.5);
grid on;ylabel('Start Doppler (kHz)');
nexttile;plot(physics.orbitStartSec,physics.dopplerRateStartHzPerSec,'-o', ...
    physics.orbitStartSec,physics.peakAbsDopplerRateHzPerSec,'--s','LineWidth',1.5);
grid on;ylabel('Doppler rate (Hz/s)');legend('start','peak |rate|');
nexttile;plot(physics.orbitStartSec,physics.frameDriftBins,'-o', ...
    physics.orbitStartSec,physics.frameRangeBins,'--s','LineWidth',1.5);
grid on;xlabel('Orbit start t_0 (s)');ylabel('Physical bins');
legend('signed frame drift','frame range');title(tiles,'EXP1 physical regimes');
path = fullfile(out,'EXP1_B_DOPPLER_REGIME.png');
exportgraphics(figureHandle,path,'Resolution',220);close(figureHandle);files(end+1)=path;

if isfile(deltaPath)
    delta = readtable(deltaPath);
    if ~isempty(delta)
        figureHandle = figure('Visible','off','Color','w','Position',[100 100 900 500]);
        baselineNames = unique(delta.baseline,'stable');
        deltaSnrs = unique(delta.snrDb,'stable');
        for baselineIndex = 1:numel(baselineNames)
            for snrIndex = 1:numel(deltaSnrs)
                rows = strcmp(delta.baseline,baselineNames{baselineIndex}) & ...
                    delta.snrDb == deltaSnrs(snrIndex);
                data = sortrows(delta(rows,:),{'orbitStartSec'});
                if isempty(data)
                    continue
                end
                label = sprintf('%s @ %.2f dB', ...
                    baselineNames{baselineIndex},deltaSnrs(snrIndex));
                errorbar(data.orbitStartSec,data.deltaSer, ...
                    data.deltaSer-data.ciLow,data.ciHigh-data.deltaSer,'-o', ...
                    'LineWidth',1.4,'DisplayName',label);hold on
            end
        end
        yline(0,':k','HandleVisibility','off');
        grid on;xlabel('Orbit start t_0 (s)');
        ylabel('\DeltaSER = SER_{baseline} - SER_{Stage55}');legend('Location','best');
        path = fullfile(out,'EXP1_C_PAIRED_DELTA_SER.png');
        exportgraphics(figureHandle,path,'Resolution',220);close(figureHandle);files(end+1)=path;
    end
end

selected = ismember(symbol.orbitStartSec,[-366 -91.5 0]);
diagnostic = symbol(selected & ismember(symbol.method,{'Stage55','Stage55-VP-off'}),:);
if ~isempty(diagnostic)
    figureHandle = figure('Visible','off','Color','w','Position',[100 100 1150 650]);
    tiles = tiledlayout(figureHandle,2,3,'TileSpacing','compact');
    positions = [-366 -91.5 0];
    for positionIndex = 1:3
        positionRows = diagnostic.orbitStartSec == positions(positionIndex);
        nexttile(positionIndex);
        groups = unique(diagnostic.method(positionRows),'stable');
        diagnosticSnrs = unique(diagnostic.snrDb(positionRows),'stable');
        for group = 1:numel(groups)
            for snrIndex = 1:numel(diagnosticSnrs)
                rows = positionRows & strcmp(diagnostic.method,groups{group}) & ...
                    diagnostic.snrDb == diagnosticSnrs(snrIndex);
                data = diagnostic(rows,:);
                if isempty(data)
                    continue
                end
                label = sprintf('%s @ %.2f dB', ...
                    groups{group},diagnosticSnrs(snrIndex));
                plot(data.dataSymbolIndex,data.ser,'LineWidth',1.2, ...
                    'DisplayName',label);hold on
            end
        end
        grid on;title(sprintf('t_0 = %.1f s',positions(positionIndex)));
        ylabel('Per-position SER');legend('Location','best');
        nexttile(positionIndex+3);
        for group = 1:numel(groups)
            for snrIndex = 1:numel(diagnosticSnrs)
                rows = positionRows & strcmp(diagnostic.method,groups{group}) & ...
                    diagnostic.snrDb == diagnosticSnrs(snrIndex);
                data = diagnostic(rows,:);
                if isempty(data)
                    continue
                end
                label = sprintf('%s @ %.2f dB', ...
                    groups{group},diagnosticSnrs(snrIndex));
                plot(data.dataSymbolIndex,data.cfoRmseHz,'LineWidth',1.2, ...
                    'DisplayName',label);hold on
            end
        end
        grid on;xlabel('Data symbol index');ylabel('Residual CFO RMSE (Hz)');
    end
    title(tiles,'Stage55 payload-position diagnostics');
    path = fullfile(out,'EXP1_D_FRAME_DIAGNOSTICS.png');
    exportgraphics(figureHandle,path,'Resolution',220);close(figureHandle);files(end+1)=path;
end
end
