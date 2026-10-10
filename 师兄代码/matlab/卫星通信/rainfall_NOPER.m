% 降雨量

figure;
subplot(2,1,1);
bar(1:2,[1 1]);hold on;
bar(3:12,0.5*ones(1,10));hold on;
bar(13:15,zeros(1,3));hold on;
bar(16:24,0.1*ones(1,9));
xticks(1:24);
xticklabels({'7:00','8:00','9:00','10:00','11:00','12:00','13:00','14:00','15:00','16:00',...
    '17:00','18:00','19:00','20:00','21:00','22:00','23:00',...
    '00:00','1:00','2:00','3:00','4:00','5:00','6:00'});
xlabel('Time UTC');
yticks([0 0.1 0.5 1]);
yticklabels({'0','0-10','25-50','50-100'});
ylabel('降雨量 (mm)');

load('Com_New_Old_BER_PER_Throughput.mat')
subplot(2,1,2);
bar(1:8,Com_PER);
ylabel('PER');grid on
b1=legend('优化调整帧格式','原帧格式','Location','northoutside');
b1.NumColumns=2;
xticks(1:8)
xticklabels({'7:00-9:00','10:00-12:00','13:00-15:00','16:00-18:00','19:00-21:00','22:00-00:00','1:00-3:00','4:00-6:00'})
xlabel('Time UTC');