%% 8个前导码采用导数法估计多普勒；
epsilon = 0.5;
%% 
SF=12;
M=2^SF;
SNR=-20;
a=0; %前导码前八个是0
k=0:1:M-1;
xk0=exp(-1j*2*pi*k.*(-1/2+k/2/M));  %LoRa基信号的共轭
xk=exp(1j*2*pi*k.*(a/M-1/2+k/2/M)); %前导码直达径信号
xk=xk.*exp(1j*2*pi*k.*(epsilon/M)); %前导码直达径信号加多普勒
S_preamble=[xk xk xk xk xk xk xk xk];%8个前导码
%% 加噪
sigPower=sum(abs(S_preamble.*S_preamble))/M/8;
reqSNR=10^(SNR/10);
noisePower=sigPower/reqSNR;
noise=sqrt(noisePower/2)*(randn(1,8*M)+1j*randn(1,8*M));
% noise=noise/max(noise);
rk=S_preamble+noise;
% rk=rk/max(rk);
% rk=awgn(S_preamble,SNR,'measured');
%% 
alpha=0.5;
y_preamble=zeros(1,M);
for o=1:8
    r_preamble=rk((o-1)*M+1:o*M);
    y_preamble_tem=abs(fft(r_preamble.*xk0))/M;
%     threshold=alpha*max(y_preamble_tem);%滤波
%     y_preamble_tem(y_preamble_tem<threshold)=0;%滤波
    y_preamble=y_preamble+y_preamble_tem;
end
y_preamble=y_preamble/8;
y_preamble(y_preamble<alpha*max(y_preamble))=0;
% figure;plot(0:M-1,y_preamble);
%% 导数法
% Es=sum(abs(y_breamble).^2);
den=0;
num=0;
for i=0:M-1
    num=num+i*y_preamble(i+1)^2;
    den=den+y_preamble(i+1)^2;
    
end
epsilon_es=num/den;