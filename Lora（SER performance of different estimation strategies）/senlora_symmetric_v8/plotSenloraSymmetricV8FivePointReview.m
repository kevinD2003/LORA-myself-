function output = plotSenloraSymmetricV8FivePointReview()
%PLOTSENLORASYMMETRICV8FIVEPOINTREVIEW Five requested negative-orbit points.

projectRoot = fileparts(fileparts(mfilename('fullpath')));
codexRoot = fileparts(projectRoot);
resultRoot = fullfile(projectRoot,'results','senlora_symmetric_v8', ...
    'joint_block_review');
reviewPath = fullfile(resultRoot,'REVIEW_RAW_POINTS.csv');
theoryPath = fullfile(codexRoot,'Lora(theory)','ideal_stage55_ser', ...
    'results','ideal_ser_theory.csv');
if ~isfile(reviewPath) || ~isfile(theoryPath)
    error('EXP5V8:FivePointInput','Review or theory table is missing.');
end

review = readtable(reviewPath);
theory = readtable(theoryPath);
targetTimeSec = [-366;-274.5;-183;-91.5;0];
theoryRow = theory(abs(theory.snrDb+21)<1e-12,:);
if height(theoryRow)~=1
    error('EXP5V8:FivePointTheory','Expected one exact theory row at -21 dB.');
end
theorySer = theoryRow.ser;

selected = review([],:);
for index = 1:numel(targetTimeSec)
    row = review(review.sideIndex==1 & ...
        abs(review.orbitStartSec-targetTimeSec(index))<1e-9,:);
    if height(row)~=1
        error('EXP5V8:FivePointSelection', ...
            'Expected one Review point at %.9g s.',targetTimeSec(index));
    end
    selected = [selected;row]; %#ok<AGROW>
end

senloraNotBetterThanIdeal = selected.jointSer>=selected.idealSer;
if ~all(senloraNotBetterThanIdeal)
    error('EXP5V8:FivePointOrdering', ...
        'A measured SenLoRa point is below empirical Ideal.');
end
fivePoint = table(targetTimeSec,selected.packets, ...
    selected.jointRawErrors,selected.idealRawErrors, ...
    selected.jointSer,selected.idealSer, ...
    repmat(theorySer,numel(targetTimeSec),1), ...
    senloraNotBetterThanIdeal, ...
    'VariableNames',{'orbitStartSec','packets','senloraRawErrors', ...
    'idealRawErrors','senloraSer','empiricalIdealSer', ...
    'exactTheorySer','senloraNotBetterThanIdeal'});
tablePath = fullfile(resultRoot,'REVIEW_FIVE_POINT_NEGATIVE.csv');
writetable(fivePoint,tablePath);

displayFloor = 1e-5;
f = figure('Visible','off','Color','w','Position',[100 100 1080 680]);
hold on
localMeasuredLine(targetTimeSec,fivePoint.senloraSer,displayFloor, ...
    'o','v',9,[0 0.4470 0.7410],'SenLoRa V8');
localMeasuredLine(targetTimeSec,fivePoint.empiricalIdealSer,displayFloor, ...
    '^','x',7,[0.8500 0.3250 0.0980],'Empirical Ideal');
semilogy(targetTimeSec,fivePoint.exactTheorySer,'-k', ...
    'LineWidth',1.6,'DisplayName','Exact AWGN theory');
set(gca,'YScale','log');
grid on;grid minor
xlim([-380 10]);
ylim([displayFloor 1]);
xticks(targetTimeSec);
xticklabels(compose('%.1fs',targetTimeSec));
xtickangle(25);
yticks(10.^(-5:0));
xlabel('Frame start time (s)');
ylabel('SER');
title({'SenLoRa V8 five requested negative-orbit points', ...
    '100 Review packets per point; exact theory is time-invariant', ...
    'Exact-zero measurements are floor markers and are not connected'});
legend('Location','northeast');
figurePath = fullfile(resultRoot,'REVIEW_FIVE_POINT_SER_1E-5_TO_1.png');
exportgraphics(f,figurePath,'Resolution',220);
close(f);

output = struct('table',fivePoint,'tablePath',tablePath, ...
    'figurePath',figurePath,'theorySer',theorySer, ...
    'allSenloraNotBetterThanIdeal',all(senloraNotBetterThanIdeal));
end

function localMeasuredLine( ...
        x,raw,floorValue,marker,floorMarker,floorSize,color,name)
connected = raw;
connected(raw<floorValue) = NaN;
semilogy(x,connected,['-' marker],'Color',color,'LineWidth',1.4, ...
    'MarkerSize',7,'DisplayName',name);
zero = raw==0;
if any(zero)
    semilogy(x(zero),repmat(floorValue,sum(zero),1),floorMarker, ...
        'Color',color,'MarkerSize',floorSize,'LineWidth',1.4, ...
        'HandleVisibility','off');
end
end
