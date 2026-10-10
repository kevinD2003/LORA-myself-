function outputPath = plotSenloraSymmetricV8ReviewLogSer()
%PLOTSENLORASYMMETRICV8REVIEWLOGSER Render Review SER on 1e-5 to 1 range.

projectRoot = fileparts(fileparts(mfilename('fullpath')));
resultRoot = fullfile(projectRoot,'results','senlora_symmetric_v8', ...
    'joint_block_review');
summaryPath = fullfile(resultRoot,'REVIEW_RAW_POINTS.csv');
if ~isfile(summaryPath)
    error('EXP5V8:ReviewPlot','Review raw-point table is missing.');
end
summary = readtable(summaryPath);

displayFloor = 1e-5;
displayCeiling = 1;
negativeHalf = summary.orbitStartSec>=-400 & summary.orbitStartSec<=0;
x = summary.orbitStartSec(negativeHalf);
values = {summary.jointSer(negativeHalf), ...
    summary.v6Ser(negativeHalf),summary.idealSer(negativeHalf)};
names = {'Joint-block V8','V6-native','Ideal'};
markers = {'o','s','^'};
colors = lines(3);

f = figure('Visible','off','Color','w','Position',[100 100 1120 680]);
hold on
for method = 1:numel(values)
    raw = values{method};
    connected = raw;
    connected(raw<displayFloor) = NaN;
    semilogy(x,connected,['-' markers{method}], ...
        'Color',colors(method,:),'LineWidth',1.4, ...
        'MarkerSize',7,'DisplayName',names{method});
    below = raw<displayFloor;
    if any(below)
        semilogy(x(below),repmat(displayFloor,sum(below),1),'v', ...
            'Color',colors(method,:),'MarkerSize',7, ...
            'LineWidth',1.2,'HandleVisibility','off');
    end
end
grid on;grid minor
set(gca,'YScale','log');
xlabel('Frame start time (s)');
ylabel('Raw SER');
xlim([-400 0]);
ylim([displayFloor displayCeiling]);
yticks(10.^(-5:0));
title({'SenLoRa V8 independent Review raw SER: negative half', ...
    'Measured points connected directly; no fit or smoothing', ...
    'Exact-zero floor markers are shown but not connected'});
legend('Location','northeast');
outputPath = fullfile(resultRoot, ...
    'REVIEW_RAW_SER_NEGATIVE_HALF_1E-5_TO_1.png');
exportgraphics(f,outputPath,'Resolution',220);
close(f);
end
