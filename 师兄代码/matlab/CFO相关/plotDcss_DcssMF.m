%% 画图，画出差分编码和差分编码+匹配滤波的误码率曲线
c=['k';'m';'c';'b';'g';'r'];
% c=[0 0 0;
%     0 0 1;
%     1 0 0;
%     1 0.5 0;
%     1 0 1;
%     0.41961 0.55686 0.13725;];
m=['s';'s';'s';'s';'s';'s'];
d=['o';'o';'o';'o';'o';'o'];
figure;
for f=1:length(fd)
    semilogy(SNR,BER_MF(f,:),'LineStyle','--','Color',c(f,:),'Marker',m(f));hold on;
    semilogy(SNR,BER_DCSS(f,:),'LineStyle','-','Color',c(f,:),'Marker',d(f));hold on;
end
grid on;
xlabel('SNR');ylabel('BER');
ylim([10^-6 1]);
legend('MF,fd=0.5*\Deltaf','DCSS,fd=0.5*\Deltaf','MF,fd=0.6*\Deltaf','DCSS,fd=0.6*\Deltaf','MF,fd=0.7*\Deltaf','DCSS,fd=0.7*\Deltaf','MF,fd=0.8*\Deltaf','DCSS,fd=0.8*\Deltaf','MF,fd=0.9*\Deltaf','DCSS,fd=0.9*\Deltaf','MF,fd=1.0*\Deltaf','DCSS,fd=1.0*\Deltaf');



figure;
for ff=1:3
    semilogy(SNR,BER_MF(ff,:),'LineStyle','--','Color',c(ff,:),'Marker',m(ff));hold on;
    semilogy(SNR,BER_DCSS(ff,:),'LineStyle','-','Color',c(ff,:),'Marker',d(ff));hold on;
end
grid on;
xlabel('SNR');ylabel('BER');
ylim([10^-6 1]);
legend('MF,fd=0.5*\Deltaf','DCSS,fd=0.5*\Deltaf','MF,fd=0.6*\Deltaf','DCSS,fd=0.6*\Deltaf','MF,fd=0.7*\Deltaf','DCSS,fd=0.7*\Deltaf');



figure;
for fff=4:length(fd)
    semilogy(SNR,BER_MF(fff,:),'LineStyle','--','Color',c(fff,:),'Marker',m(fff));hold on;
    semilogy(SNR,BER_DCSS(fff,:),'LineStyle','-','Color',c(fff,:),'Marker',d(fff));hold on;
end
grid on;
xlabel('SNR');ylabel('BER');
ylim([10^-6 1]);
legend('MF,fd=0.8*\Deltaf','DCSS,fd=0.8*\Deltaf','MF,fd=0.9*\Deltaf','DCSS,fd=0.9*\Deltaf','MF,fd=1.0*\Deltaf','DCSS,fd=1.0*\Deltaf');

