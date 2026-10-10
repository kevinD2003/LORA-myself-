SF=7;
M=2^SF;
% a=randi([0 M-1]);
a=127;
% a=M/2;
% a=6;
k=0:0.1:M-1;
epsilon=0;
xk0=exp(-1j*2*pi*k.*(-1/2+k/2/M));%LoRa基信号的共轭
xk=exp(1j*2*pi*k.*(a/M-1/2+k/2/M+epsilon/M));%直达径信号
rk=xk;
Yq=abs(fft(rk.*xk0)/10/M);
figure;
stem(0:0.1:M-1,Yq,'Marker','none','Linewidth',1.5);hold on;
% ylim([0 1]);
xlim([0 M-1])



