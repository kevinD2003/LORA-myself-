%% LoRa under Carrier Frequency Offset with Rayleigh Fading
%% MF 算法
%% CFO + Rayleigh Fading 
%带频偏的LoRa计算误码率；
B=250e3;
SF=12;
M=2^SF;
SNR=-25:20;
N_error_max=2000000;
times=[100*ones(1,length(SNR))];
% times=[1000*ones(1,11) 10000*ones(1,9) 100000*ones(1,10) 500000*ones(1,6) 1000000*ones(1,10)];
epsilon=[0.8];
N_upchirp=8;% 采用8个upchirp做匹配滤波
N_payload=10;
BER_MF=zeros(1,length(SNR));
tic;
%% MF 匹配滤波法
h=waitbar(0,['SF=' num2str(SF) ',MF, CFO + Rayleigh Fading']);
for i=1:1:length(SNR)
   error_mf=0;
   for j=1:1:times(i)
       [errormf]=MF(M,epsilon,SNR(i),N_upchirp,N_payload);
       error_mf=error_mf+errormf;
       if error_mf > N_error_max
           break;
       end
       N=j;
   end
   BER_MF(i)=error_mf/(N*N_payload)/2;
   if BER_MF(i)<1E-6
       break;
   end
   
   waitbar(i/length(SNR),h,['SF=' num2str(SF) ',MF, CFO + Rayleigh Fading.   SNR=' num2str(SNR(i))]);
end
toc;
close(h);


%%
figure;
semilogy(SNR,BER_MF,'m-s');hold on;
xlabel('SNR(dB)');ylabel('BER');
grid on;
legend(['MF,Rayleigh Fading,' num2str(N_upchirp) ' upchirps']);

%% MF算法
function [error1]=MF(M,epsilon,SNR,N_upchirp,N_payload)
error1=0;
aa=randi([0 M-1],1,N_payload);
alpha=0.25;
k=0:1:M-1;  
% xk=exp(1j*2*pi*k.*(aa/M-1/2+k/2/M+fd/B));
% xk_preamble=exp(1j*2*pi*k.*(-1/2+k/2/M+fd/B));%前导符号
xk_preamble=zeros(1,M*N_upchirp);
xk_payload=zeros(1,M*N_payload);
xk_pre=exp(1j*2*pi*k.*(-1/2+k/2/M+epsilon/M));%前导符号
% 前导码
for i=1:1:N_upchirp
    xk_preamble((i-1)*M+1:i*M)=xk_pre;
end
% 数据块
for j=1:1:N_payload
    xk_payload((j-1)*M+1:j*M)=exp(1j*2*pi*k.*(aa(j)/M-1/2+k/2/M+epsilon/M));
end

Sd=[xk_preamble xk_payload];

%% 手动添加高斯噪声
sigPower=sum(abs(Sd.*Sd))/length(Sd);
reqSNR=10^(SNR/10);
noisePower=sigPower/reqSNR;
noise=sqrt(noisePower/2)*(randn(1,length(Sd))+1j*randn(1,length(Sd)));
%% 瑞利信道
omega = 1;
h_rayleigh = sqrt(omega/2) *(randn(1,1) + 1i*randn(1,1));
rk1=h_rayleigh*Sd+noise;

rk_preamble=rk1(1:N_upchirp*M);
rk_payload=rk1(N_upchirp*M+1:(N_payload+N_upchirp)*M);

xk0=exp(-1j*2*pi*k.^2/(2*M)+1j*pi*k);
y_preamble=zeros(1,M);
%N_upchirps个upchirp的情况
for o=1:N_upchirp
    r_preamble=rk_preamble((o-1)*M+1:o*M);
    y_preamble_tem=abs(fft(r_preamble.*xk0))/M;
    threshold=alpha*max(y_preamble_tem);
    y_preamble_tem(y_preamble_tem<threshold)=0;%滤波
    y_preamble=y_preamble+y_preamble_tem;
end
y_preamble=y_preamble/N_upchirp;%取平均

for o=1:1:N_payload
    y_payload_tmp=rk_payload((o-1)*M+1:o*M);
    y_payload=abs(fft(y_payload_tmp.*xk0))/M;
    %圆周相关运算
    R=zeros(1,M);
    for d=1:M
        y_tem=[y_payload(d:end) y_payload(1:d-1)];
        R(d)=sum(y_preamble.*y_tem);
    end
    %解调
    [~,decision]=max(R);
    if ((decision-1) ~= aa(o))
        error1 = error1 + 1;
    end

end
% o = N_upchirp;
% y_payload=abs(fft(rk1(o*M+1:end).*xk0))/M;
% 


end
