%% 画图；解调域信号示意图
B=125e3;
SF=7;
M=2^SF;
k=0:1:M-1;
aa=60;
epsilon=[0 30 0.6 -30.5];

xk0=exp(-1j*2*pi*k.*(-1/2+k/M/2));
% xk=awgn(xk,-5);
% y1=abs(fft(xk1.*xk0))/M;
figure;
c=[[1 0 0];[0.07 0.62 1];[0.39 0.83 0.07];[0.93 0.69 0.13]];
LS=['-';'-';':';'-'];
% m=['none';'none';'none';'.'];
for i=1:length(epsilon)
    subplot(length(epsilon),1,i);
    xk1=exp(1j*2*pi*k.*(aa/M-1/2+k/M/2+epsilon(i)/M));%带频偏的调制公式
    y1=abs(fft(xk1.*xk0))/M;
    stem(0:M-1,y1,'Marker','none','Linewidth',1.5,'LineStyle',LS(i),'Color',c(i,:));hold on
    xlim([0 M-1]);ylim([0 1])
    xlabel('Frequency bin,q');ylabel('|Y_q|/M');
    legend(['ε = ',num2str(epsilon(i))]);
end 

% xk2=exp(1j*2*pi*k.*(aa/M-1/2+k/M/2+epsilon(2)/M));%带频偏的调制公式
% y2=abs(fft(xk1.*xk0))/M;
% subplot(4,1,2);
% stem(0:M-1,y,'Marker','none','Linewidth',1.5);hold on
% xlim([0 M-1]);
% xlabel('Frequency bin,q');ylabel('|Y_q|/M');
% legend(['epsilon=',num2str(fd/(B/M)),'SF=7']);
% 
% 
% xk3=exp(1j*2*pi*k.*(aa/M-1/2+k/M/2+epsilon(3)/M));%带频偏的调制公式
% y2=abs(fft(xk1.*xk0))/M;
% subplot(4,1,3);
% stem(0:M-1,y,'Marker','none','Linewidth',1.5);hold on
% xlim([0 M-1]);
% xlabel('Frequency bin,q');ylabel('|Y_q|/M');
% legend(['epsilon=',num2str(fd/(B/M)),'SF=7']);