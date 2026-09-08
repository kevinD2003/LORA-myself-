SNR=-25:20;
SF=12;
M=2^SF;
%% 计算瑞利信道理论值
Pb=zeros(1,length(SNR));
H=harmonic(M-1);%调和数
for i=1:length(SNR)
    snr=10^(SNR(i)/10);
    Pb(i)=0.5*(qfunc(-sqrt(2*H))-sqrt(M*snr/(M*snr+1))*exp(-2*H/(2*(M*snr+1)))*qfunc(sqrt((M*snr)/(M*snr))*(-sqrt(2*H)+sqrt(2*H)/(M*snr+1))));
end
figure;
semilogy(SNR,Pb,'LineStyle','-','Color','r','Marker','+');
grid on;