function files=buildV4ExperimentBNativeRegimePlotsP10()
%BUILDV4EXPERIMENTBNATIVEREGIMEPLOTSP10 Plot native P10 by Doppler regime.

root=v4SetupPaths();
reportDir=fullfile(root,'results','reports');
formalDir=fullfile(root,'results','formal','track_b','B_AWGN_NATIVE');
snrs=(-30:-21).';
methodNames={'Huang','Stage55','Paper'};
regionNames={ ...
    'High CFO / low rate (elevation < 30 deg)', ...
    'High rate / low CFO (elevation 30-50 deg)'};
regionKeys={'high_cfo_low_rate','high_rate_low_cfo'};

rawErrors=zeros(10,3,4,2);
denominators=zeros(10,3,4,2);
for snrIndex=1:numel(snrs)
    passDir=fullfile(formalDir,sprintf('snr_%+03d',snrs(snrIndex)),'passes');
    for passIndex=1:10
        path=fullfile(passDir,sprintf('pass_%02d.mat',passIndex));
        if ~isfile(path)
            error('V4:NativeRegimePlot','Missing SNR %g pass %d.', ...
                snrs(snrIndex),passIndex);
        end
        loaded=load(path,'result');
        result=loaded.result;
        if ndims(result.rawErrors)~=3 || size(result.rawErrors,3)<2
            error('V4:NativeRegimePlot','Native pass lacks region counts.');
        end
        rawErrors(snrIndex,:,:,:)=rawErrors(snrIndex,:,:,:)+ ...
            reshape(result.rawErrors(:,:,1:2),1,3,4,2);
        denominators(snrIndex,:,:,:)=denominators(snrIndex,:,:,:)+ ...
            reshape(result.denominators(:,:,1:2),1,3,4,2);
    end
end

metrics=rawErrors./denominators;
plotMetrics=metrics;
zeroMask=metrics==0;
plotMetrics(zeroMask)=0.5./denominators(zeroMask);

rows=cell(10*3*2,15);
row=0;
for region=1:2
    for snrIndex=1:10
        for method=1:3
            row=row+1;
            rows(row,:)={regionKeys{region},regionNames{region},snrs(snrIndex), ...
                methodNames{method},10, ...
                rawErrors(snrIndex,method,1,region),denominators(snrIndex,method,1,region), ...
                metrics(snrIndex,method,1,region), ...
                rawErrors(snrIndex,method,2,region),denominators(snrIndex,method,2,region), ...
                metrics(snrIndex,method,2,region), ...
                rawErrors(snrIndex,method,3,region),denominators(snrIndex,method,3,region), ...
                metrics(snrIndex,method,3,region), ...
                any(zeroMask(snrIndex,method,1:3,region),'all')};
        end
    end
end
summary=cell2table(rows,'VariableNames',{ ...
    'regionKey','regionDescription','snrDb','method','completePasses', ...
    'symbolErrors','symbolCount','ser','hardBitErrors','hardBitCount','hardBer', ...
    'mlBitErrors','mlBitCount','mlBer','containsZeroErrorMetric'});
csvPath=fullfile(reportDir,'V30_EXPERIMENT_B_NATIVE_P10_DOPPLER_REGIME_SUMMARY.csv');
writetable(summary,csvPath);

colors=[0.35 0.35 0.35;0.8500 0.3250 0.0980;0 0.4470 0.7410];
styles={'-.^','-s','--o'};

serFigure=figure('Visible','off','Color','w','Position',[100 100 1200 480]);
serLayout=tiledlayout(serFigure,1,2,'TileSpacing','compact','Padding','compact');
for region=1:2
    nexttile;
    for method=1:3
        semilogy(snrs,squeeze(plotMetrics(:,method,1,region)),styles{method}, ...
            'Color',colors(method,:),'LineWidth',1.8,'MarkerSize',6, ...
            'DisplayName',methodNames{method});
        hold on
    end
    grid on;grid minor;xlabel('SNR (dB)');ylabel('SER');
    title(regionNames{region});xlim([-30 -21]);ylim([1e-6 1.1]);
    legend('Location','southwest');
end
title(serLayout,{'Experiment B Native-overhead AWGN P10: SER by Doppler regime', ...
    'Zero-error points are displayed at 0.5/N'},'FontWeight','bold');
serPng=fullfile(reportDir,'V30_EXPERIMENT_B_NATIVE_P10_SER_BY_DOPPLER_REGIME.png');
serFig=fullfile(reportDir,'V30_EXPERIMENT_B_NATIVE_P10_SER_BY_DOPPLER_REGIME.fig');
exportgraphics(serFigure,serPng,'Resolution',220);savefig(serFigure,serFig);close(serFigure);

berFigure=figure('Visible','off','Color','w','Position',[100 100 1200 850]);
berLayout=tiledlayout(berFigure,2,2,'TileSpacing','compact','Padding','compact');
metricIndex=[2 3];metricNames={'Hard BER','ML BER'};
for region=1:2
    for metric=1:2
        nexttile((region-1)*2+metric);
        for method=1:3
            semilogy(snrs,squeeze(plotMetrics(:,method,metricIndex(metric),region)), ...
                styles{method},'Color',colors(method,:),'LineWidth',1.8, ...
                'MarkerSize',6,'DisplayName',methodNames{method});
            hold on
        end
        grid on;grid minor;xlabel('SNR (dB)');ylabel(metricNames{metric});
        title(sprintf('%s - %s',regionNames{region},metricNames{metric}));
        xlim([-30 -21]);ylim([1e-7 1]);legend('Location','southwest');
    end
end
title(berLayout,{'Experiment B Native-overhead AWGN P10: BER by Doppler regime', ...
    'Zero-error points are displayed at 0.5/N'},'FontWeight','bold');
berPng=fullfile(reportDir,'V30_EXPERIMENT_B_NATIVE_P10_BER_BY_DOPPLER_REGIME.png');
berFig=fullfile(reportDir,'V30_EXPERIMENT_B_NATIVE_P10_BER_BY_DOPPLER_REGIME.fig');
exportgraphics(berFigure,berPng,'Resolution',220);savefig(berFigure,berFig);close(berFigure);

files=struct('sourceDirectory',formalDir,'summaryCsv',csvPath, ...
    'serPng',serPng,'serFig',serFig,'berPng',berPng,'berFig',berFig, ...
    'regionBoundaryElevationDeg',30,'completePassesPerSnr',10, ...
    'zeroErrorPlotConvention','0.5/N');
end
