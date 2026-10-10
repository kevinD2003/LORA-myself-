function output = plotSenloraSymmetricV8CaseSer()
%PLOTSENLORASYMMETRICV8CASESER Case1/Case2 SER at the available -21 dB.

projectRoot = fileparts(fileparts(mfilename('fullpath')));
root = fullfile(projectRoot,'results','senlora_symmetric_v8', ...
    'five_point_1000');
rawPath = fullfile(root,'FIVE_POINT_1000_RAW_PACKETS.csv');
summaryPath = fullfile(root,'FIVE_POINT_1000_SUMMARY.csv');
if ~isfile(rawPath) || ~isfile(summaryPath)
    error('EXP5V8:CaseSerInput','Five-point 1000-packet results are missing.');
end
raw = readtable(rawPath);
summary = readtable(summaryPath);
if height(raw)~=5000 || height(summary)~=5 || ...
        any(raw.senloraFailed) || any(raw.idealFailed)
    error('EXP5V8:CaseSerInput','Five-point source data are incomplete.');
end

caseNames = ["Case 1";"Case 2"];
caseTimes = [-366;0];
pointIndices = [1;5];
methodNames = ["SenLoRa V8";"Empirical Ideal"];
symbolsPerPacket = 112;
draws = 10000;
rows = cell(4,10);
row = 0;
for caseIndex = 1:2
    point = pointIndices(caseIndex);
    data = sortrows(raw(raw.pointIndex==point,:),'packetId');
    if height(data)~=1000 || any(data.orbitStartSec~=caseTimes(caseIndex))
        error('EXP5V8:CaseSerSelection','Case packet selection is invalid.');
    end
    errorSeries = {data.senloraRawErrors,data.idealRawErrors};
    for method = 1:2
        row = row+1;
        errors = errorSeries{method};
        estimate = sum(errors)/(height(data)*symbolsPerPacket);
        stream = RandStream('mt19937ar', ...
            'Seed',1032505000+100*caseIndex+method);
        bounds = localClusterBounds(errors,symbolsPerPacket,stream,draws);
        if method==1
            rawErrors = summary.senloraRawErrors(summary.pointIndex==point);
        else
            rawErrors = summary.idealRawErrors(summary.pointIndex==point);
        end
        if rawErrors~=sum(errors)
            error('EXP5V8:CaseSerCount','Raw error count mismatch.');
        end
        rowSummary = summary(summary.pointIndex==point,:);
        rows(row,:) = {caseNames(caseIndex),caseTimes(caseIndex), ...
            -21,methodNames(method),height(data),rawErrors,estimate, ...
            bounds(1),bounds(2),rowSummary.exactTheorySer};
    end
end
caseSer = cell2table(rows,'VariableNames',{ ...
    'caseName','orbitStartSec','snrDb','method','packets', ...
    'rawErrors','ser','lower95','upper95','exactTheorySer'});
tablePath = fullfile(root,'CASE1_CASE2_SER.csv');
writetable(caseSer,tablePath);

combinedPath = fullfile(root,'CASE1_CASE2_SER.png');
f = figure('Visible','off','Color','w','Position',[100 100 1120 580]);
layout = tiledlayout(1,2,'TileSpacing','compact','Padding','compact');
for caseIndex = 1:2
    ax = nexttile;
    localCaseAxes(ax,caseSer,caseNames(caseIndex));
end
title(layout,'Frozen SenLoRa V8 SER at SNR = -21 dB, 1000 packets per case');
exportgraphics(f,combinedPath,'Resolution',220);
close(f);

case1Path = fullfile(root,'CASE1_SER.png');
case2Path = fullfile(root,'CASE2_SER.png');
localSingleFigure(caseSer,"Case 1",case1Path);
localSingleFigure(caseSer,"Case 2",case2Path);
output = struct('table',caseSer,'tablePath',tablePath, ...
    'combinedPath',combinedPath,'case1Path',case1Path, ...
    'case2Path',case2Path);
end

function bounds = localClusterBounds(errors,symbolsPerPacket,stream,draws)
n = numel(errors);
samples = zeros(draws,1);
for draw = 1:draws
    indices = randi(stream,n,n,1);
    samples(draw) = sum(errors(indices))/(n*symbolsPerPacket);
end
bounds = prctile(samples,[2.5 97.5]);
end

function localCaseAxes(ax,caseSer,caseName)
axes(ax);
data = caseSer(caseSer.caseName==caseName,:);
x = [1 2];
colors = [0 0.4470 0.7410;0.8500 0.3250 0.0980];
markers = {'o','^'};
hold on
for method = 1:2
    lower = data.ser(method)-data.lower95(method);
    upper = data.upper95(method)-data.ser(method);
    errorbar(x(method),data.ser(method),lower,upper,markers{method}, ...
        'Color',colors(method,:),'MarkerFaceColor','w', ...
        'MarkerSize',8,'LineWidth',1.5,'CapSize',12);
    text(x(method),1.10*data.upper95(method), ...
        sprintf('%d / %d',data.rawErrors(method), ...
        data.packets(method)*112),'HorizontalAlignment','center');
end
yline(data.exactTheorySer(1),'--k','Exact AWGN theory', ...
    'LineWidth',1.3,'LabelHorizontalAlignment','center');
set(gca,'YScale','log');
xlim([0.5 2.5]);ylim([3e-5 4e-4]);
xticks(x);xticklabels(data.method);
ylabel('SER');grid on;grid minor
title(sprintf('%s: t_0 = %.1f s',caseName,data.orbitStartSec(1)));
end

function localSingleFigure(caseSer,caseName,path)
f = figure('Visible','off','Color','w','Position',[100 100 650 560]);
ax = axes(f);
localCaseAxes(ax,caseSer,caseName);
subtitle('SNR = -21 dB, 1000 packets; whiskers are packet bootstrap 95% intervals');
exportgraphics(f,path,'Resolution',220);
close(f);
end
