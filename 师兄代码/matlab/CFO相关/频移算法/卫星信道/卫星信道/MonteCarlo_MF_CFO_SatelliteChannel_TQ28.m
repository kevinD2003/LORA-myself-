%% 天启28星
% SF=7,B=125k;preamble:8,payload:22;883s,每秒钟33帧。
% SF=12,B=125k;preamble:8,payload:22;883s,每秒钟1帧。
%带频偏的LoRa计算误码率；
load('TQ28_CFO.mat');
B = 125e3;
SF=7;
M = 2^SF;
N_frame=33;
N_upchirp=8;
N_payload=22+(8-N_upchirp);%数据块的装载
times=883;
SNR=-12:0;
BER_MF=zeros(1,length(SNR));
tic;
%% MF 匹配滤波法
h2=waitbar(0,['MF,SF=' num2str(SF) ' TQ28']);
for i=1:1:length(SNR)
    error_mf=0;
   for j=1:1:times
       epsilon = F_cfo(j) * M / B;
       for jj=1:N_frame
           [errormf]=MF(M,epsilon,SNR(i),N_payload,N_upchirp);
           error_mf=error_mf+errormf;
       end
   end
   BER_MF(i)=error_mf/(N_frame*N_payload*times)/2;
   if BER_MF(i)<1E-6
       break;
   end
   waitbar(i/length(SNR),h2,['SF=' num2str(SF) ',SNR=' num2str(SNR(i))]);
end
toc;
close(h2);


%%
figure;
semilogy(SNR,BER_MF,'m-s');hold on;
xlabel('SNR(dB)');ylabel('BER');
grid on;
legend(['MF,SF=' num2str(SF) ',TQ28']);

%% MF算法
function [error1]=MF(M,epsilon,SNR,N_payload,N_upchirp)
error1=0;
aa=randi([0 M-1], 1, N_payload);
k=0:1:M-1;
%% 调制
xk_payload=zeros(1,M*N_payload);
for i=1:N_payload
    xk_payload((i-1)*M+1:i*M)=exp(1j*2*pi*k.*(aa(i)/M-1/2+k/2/M+epsilon/M));
end
xk_pre=exp(1j*2*pi*k.*(-1/2+k/2/M+epsilon/M));%前导符号
xk_preamble=zeros(1,M*N_upchirp);
for ii=1:N_upchirp
    xk_preamble((ii-1)*M+1:ii*M)=xk_pre;
end

%% 组帧
xk_frame=[xk_preamble xk_payload];
%% 加噪
rk1=awgn(xk_frame,SNR,'measured');
%% 解帧
rk_preamble=rk1(1:N_upchirp*M);
rk_payload=rk1(N_upchirp*M+1:end);
alpha=0.25;
% %% 手动添加高斯噪声
% sigPower=sum(abs(Sd.*Sd))/length(Sd);
% reqSNR=10^(SNR/10);
% noisePower=sigPower/reqSNR;
% noise=sqrt(noisePower/2)*(randn(1,length(Sd))+1j*randn(1,length(Sd)));
% %% 瑞利信道
% omega = 1;
% h_rayleigh = sqrt(omega/2) *(randn(1,1) + 1i*randn(1,1));
% rk1=h_rayleigh*Sd+noise;

xk0=exp(-1j*2*pi*k.^2/(2*M)+1j*pi*k);%基信号的共轭
y_preamble=zeros(1,M);
for o=1:N_upchirp
    r_pre=rk_preamble((o-1)*M+1:o*M);
    y_preamble_tem=abs(fft(r_pre.*xk0))/M;
    threshold=alpha*max(y_preamble_tem);
    y_preamble_tem(y_preamble_tem<threshold)=0;%滤波
    y_preamble=y_preamble+y_preamble_tem;
end
y_preamble=y_preamble/N_upchirp;%取平均
for j=1:N_payload
    y_payload=abs(fft(rk_payload((j-1)*M+1:j*M).*xk0))/M;
    %圆周相关运算
    R=zeros(1,M);
    for d=1:M
        y_tem=[y_payload(d:end) y_payload(1:d-1)];
        R(d)=sum(y_preamble.*y_tem);
    end
    %解调,传统
    [~,decision]=max(R);
    if ((decision-1) ~= aa(j))
        error1 =error1 + 1;
    end
end

end
