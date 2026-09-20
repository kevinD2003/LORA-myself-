function files=buildV4ExperimentBPlotsP10()
%BUILDV4EXPERIMENTBPLOTSP10 Plot AWGN P10 SER, hard BER and ML BER.

root=v4SetupPaths();
reportDir=fullfile(root,'results','reports');
source=fullfile(reportDir,'EXPERIMENT_B_AWGN_EXPEDITED_V2_P10.json');
data=jsondecode(fileread(source));

methodNames={'Huang','Stage55','Paper'};
colors=[0.35 0.35 0.35;0.8500 0.3250 0.0980;0 0.4470 0.7410];
styles={'-.^','-s','--o'};

serFigure=figure('Visible','off','Color','w','Position',[100 100 1200 480]);
serLayout=tiledlayout(serFigure,1,2,'TileSpacing','compact','Padding','compact');
for groupIndex=1:2
    [snr,metrics]=localMetrics(data.groups(groupIndex));
    nexttile;
    for method=1:3
        semilogy(snr,metrics(:,method,1),styles{method}, ...
            'Color',colors(method,:),'LineWidth',1.8,'MarkerSize',6, ...
            'DisplayName',methodNames{method});
        hold on
    end
    grid on;grid minor
    xlabel('SNR (dB)');ylabel('SER');
    title(localModeTitle(data.groups(groupIndex).groupName));
    xlim([-30 -21]);ylim([1e-4 1.1]);
    legend('Location','southwest');
end
title(serLayout,'Experiment B AWGN P10: SER versus SNR','FontWeight','bold');
serPng=fullfile(reportDir,'V30_EXPERIMENT_B_AWGN_P10_SER.png');
serFig=fullfile(reportDir,'V30_EXPERIMENT_B_AWGN_P10_SER.fig');
exportgraphics(serFigure,serPng,'Resolution',220);savefig(serFigure,serFig);close(serFigure);

berFigure=figure('Visible','off','Color','w','Position',[100 100 1200 850]);
berLayout=tiledlayout(berFigure,2,2,'TileSpacing','compact','Padding','compact');
metricIndex=[2 3];metricTitle={'Hard BER','ML BER'};
for groupIndex=1:2
    [snr,metrics]=localMetrics(data.groups(groupIndex));
    for column=1:2
        nexttile((groupIndex-1)*2+column);
        for method=1:3
            semilogy(snr,metrics(:,method,metricIndex(column)),styles{method}, ...
                'Color',colors(method,:),'LineWidth',1.8,'MarkerSize',6, ...
                'DisplayName',methodNames{method});
            hold on
        end
        grid on;grid minor
        xlabel('SNR (dB)');ylabel(metricTitle{column});
        title(sprintf('%s - %s',localModeTitle(data.groups(groupIndex).groupName), ...
            metricTitle{column}));
        xlim([-30 -21]);ylim([1e-5 1]);
        legend('Location','southwest');
    end
end
title(berLayout,'Experiment B AWGN P10: BER versus SNR','FontWeight','bold');
berPng=fullfile(reportDir,'V30_EXPERIMENT_B_AWGN_P10_BER.png');
berFig=fullfile(reportDir,'V30_EXPERIMENT_B_AWGN_P10_BER.fig');
exportgraphics(berFigure,berPng,'Resolution',220);savefig(berFigure,berFig);close(berFigure);

files=struct('sourceJson',source,'serPng',serPng,'serFig',serFig, ...
    'berPng',berPng,'berFig',berFig);
end

function [snr,metrics]=localMetrics(group)
points=group.points;
snr=reshape([points.snrDb],[],1);
metrics=zeros(numel(points),3,5);
for index=1:numel(points)
    metrics(index,:,:)=reshape(points(index).methodMetrics,1,3,5);
end
end

function titleText=localModeTitle(groupName)
if strcmp(groupName,'B_AWGN_CONTROLLED')
    titleText='Controlled-time';
else
    titleText='Native-overhead';
end
end
