%% 导数法；
epsilon = 0.5;
%% 
SF=7;
M=2^SF;
SNR=10;
a=100;
k=0:1:M-1;
xk0=exp(-1j*2*pi*k.*(-1/2+k/2/M));%LoRa基信号的共轭
xk=exp(1j*2*pi*k.*(a/M-1/2+k/2/M));%直达径信号
xk=xk.*exp(1j*2*pi*k.*(epsilon/M));%加多普勒
%% 加噪
sigPower=sum(abs(xk.*xk))/M;
reqSNR=10^(SNR/10);
noisePower=sigPower/reqSNR;
noise=sqrt(noisePower/2)*(randn(1,M)+1j*randn(1,M));
rk=xk+noise;
rk=rk/max(rk);
% rk=xk;
%% 
Yq=abs(fft(rk.*xk0)/M);%非相干解调
figure;stem(0:M-1,Yq);
%% 导数法
sden=0;
num=0;
for i=0:M-1
    num=num+i*Yq(i+1)^2;
    sden=sden+Yq(i+1)^2;
end
a_est=num/sden;