%% 多径+多普勒的LoRa计算误码率；
B=250e3;
% %% VehB channel
% power=[-2.5 0 -12.8 -10.0 -25.2 -16];%dB
% delay=[0 300 8900 12900 17100 20000];%ns
% hi=10.^(power/10);
% ui=ceil(B*delay*10^-9);
%% 两径信道
hi=[sqrt(0.8) sqrt(0.2)];%
% hi=[1 0.8];
% hi=[1 1];
epsilon=[0.1 0.2];
% epsilon=[0 0];
ui=[0 6];
%% 
SF=10;
M=2^SF;
SNR=-25:1:30;
times=10000000;
N_error_max=2000;
BER=zeros(1,length(SNR));
tic;
h=waitbar(0,'waiting,SF=10');
for ii=1:1:length(SNR)
    error=0;
    for iii=1:1:times
        if error<N_error_max
            [error1]=Nerror(M,epsilon,ui,hi,SNR(ii));
            error=error+error1;
            N=iii;
        else
            break;
        end
    end
    BER(1,ii)=error/N/2;
    if BER(1,ii)<1E-6
        break;
    end
    waitbar(ii/length(SNR),h,['SNR=',num2str(SNR(ii)),'dB']);
end

toc;
close(h);

%% 画图
figure;
semilogy(SNR,BER,'-o')
xlabel('SNR(dB)');ylabel('BER');
grid on;
ylim([10^-6 1]);
% legend(['SF=' num2str(SF) ',ui=' num2str(ui(2)) ',ε=' num2str(epsilon(2))] );
legend('三径信道，时延为0,6,10');
% title('先衰减再加噪 B=250kHz');
% legend(['SF=' num2str(SF) ',ε=' num2str(epsilon(1))] );
% title('多普勒+衰减，先加噪再衰减');
% title('多普勒')
% title('衰减多径小时延，先加噪再衰减');
%% 
function [aaerror]=Nerror(M,epsilon,ui,hi,SNR)
a=randi([0 M-1]);
k=0:1:M-1;
xk0=exp(-1j*2*pi*k.*(-1/2+k/2/M));%LoRa基信号的共轭
rkm=zeros(1,M);
% xk=exp(1j*2*pi*k.*(a/M-1/2+k/2/M+epsilon(1)/M));%直达径信号
xk=hi(1)*exp(1j*2*pi*k.*(a/M-1/2+k/2/M+epsilon(1)/M));%直达径信号，先衰减再加噪；
%% 手动添加高斯噪声
sigPower=sum(abs(xk.*xk))/M;
reqSNR=10^(SNR/10);
noisePower=sigPower/reqSNR;
noise=sqrt(noisePower/2)*(randn(1,M)+1j*randn(1,M));
%% 多径
for i=2:length(ui)
    xkm=hi(i)*exp(1j*2*pi*k.*(a/M-1/2+k/2/M+epsilon(i)/M));
    xk_tem=[zeros(1,ui(i)) xkm(1:M-ui(i))];
    rkm=rkm+xk_tem;
end
% rk=hi(1)*xk+rkm+noise;%先加噪再衰减；
rk=xk+rkm+noise;%先衰减再加噪
% rk=xk+noise;
% rk=awgn(xk,SNR,'measured')+rkm;
Yq=abs(fft(rk.*xk0)/M);%非相干解调
[~,decision]=max(Yq);
    if ((decision-1) ~= a)
        aaerror = 1;
    else
        aaerror = 0;
    end
end

